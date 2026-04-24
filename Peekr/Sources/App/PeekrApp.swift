import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct PeekrApp: App {
    private let bgTaskID = "com.mblieden.peekr.refresh"

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Self.handleBackgroundRefresh(task: refreshTask)
        }
        // Request notification permission on first launch - non-blocking
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    scheduleBackgroundRefresh()
                }
        }
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleBackgroundRefresh(task: BGAppRefreshTask) {
        let store = ServiceStore.shared
        let pingService = PingService.shared

        let checkTask = Task {
            // Read last known statuses before checking
            let services = await MainActor.run { store.services }

            for service in services {
                guard !Task.isCancelled else { break }
                let previousStatus = service.status

                do {
                    let result = try await pingService.check(service)
                    let newStatus: ServiceStatus
                    if let code = result.httpStatusCode {
                        newStatus = (200..<400).contains(code) || code == 401 || code == 403 ? .online : .degraded
                    } else {
                        newStatus = .online
                    }
                    await MainActor.run {
                        var updated = service
                        updated.status         = newStatus
                        updated.latencyMs      = result.latencyMs
                        updated.httpStatusCode = result.httpStatusCode
                        updated.lastChecked    = .now
                        store.update(updated)
                    }
                } catch {
                    // Service went offline - notify if it was previously up
                    if previousStatus == .online || previousStatus == .degraded {
                        await NotificationService.postOfflineAlert(for: service)
                    }
                    await MainActor.run {
                        var updated = service
                        updated.status      = .offline
                        updated.latencyMs   = nil
                        updated.lastChecked = .now
                        store.update(updated)
                    }
                }
            }
        }

        task.expirationHandler = { checkTask.cancel() }

        Task {
            _ = await checkTask.value
            task.setTaskCompleted(success: true)
        }
    }
}
