import SwiftUI
import BackgroundTasks
import UserNotifications

// MARK: - Notification name

extension Notification.Name {
    static let openSummarySchedule = Notification.Name("peekr.openSummarySchedule")
}

// MARK: - UNUserNotificationCenterDelegate

/// Handles notification taps so that tapping a summary notification navigates into the app.
private final class NotificationResponseHandler: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        if id.hasPrefix("summary-"),
           let uuid = UUID(uuidString: String(id.dropFirst("summary-".count))) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .openSummarySchedule,
                    object: nil,
                    userInfo: ["scheduleID": uuid]
                )
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - App

@main
struct PeekrApp: App {
    private let bgTaskID = "com.mblieden.peekr.refresh"
    private let notifDelegate = NotificationResponseHandler()

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Self.handleBackgroundRefresh(task: refreshTask)
        }
        // Request notification permission on first launch - non-blocking
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        UNUserNotificationCenter.current().delegate = notifDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    scheduleBackgroundRefresh()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task { @MainActor in await SummaryNotificationManager.shared.rescheduleAll() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    UNUserNotificationCenter.current().setBadgeCount(0)
                }
        }

        #if targetEnvironment(macCatalyst)
        MenuBarExtra("Peekr", systemImage: menuBarIcon) {
            MenuBarStatusView()
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private var menuBarIcon: String {
        let store = ServiceStore.shared
        if store.services.contains(where: { $0.status == .offline })   { return "exclamationmark.circle.fill" }
        if store.services.contains(where: { $0.status == .degraded })  { return "exclamationmark.triangle.fill" }
        if store.services.allSatisfy({ $0.status == .online })         { return "checkmark.circle.fill" }
        return "circle.dashed"
    }
    #endif

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
                    // Service went offline - notify if it was previously up and notifications are enabled
                    if (previousStatus == .online || previousStatus == .degraded) && service.notificationsEnabled {
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
