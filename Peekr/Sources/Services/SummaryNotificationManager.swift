import Foundation
import UserNotifications

/// Manages scheduling and content for summary notifications.
@MainActor
final class SummaryNotificationManager {
    static let shared = SummaryNotificationManager()
    private init() {}

    private let storageKey = "peekr.summarySchedules"

    var schedules: [MetricSummarySchedule] {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode([MetricSummarySchedule].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
            Task { await rescheduleAll() }
        }
    }

    // MARK: - Scheduling

    /// Cancel and re-create all UNNotificationRequests from current schedules.
    func rescheduleAll() async {
        let center = UNUserNotificationCenter.current()

        // Remove all existing summary notifications
        let pending = await center.pendingNotificationRequests()
        let ids = pending.filter { $0.identifier.hasPrefix("summary-") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let enabled = schedules.filter(\.isEnabled)
        guard !enabled.isEmpty else { return }

        let granted = await (try? center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }

        let services = ServiceStore.shared.services
        let liveMetrics = LiveDataStore.shared.metrics

        for schedule in enabled {
            guard services.contains(where: { $0.id == schedule.serviceID }) else { continue }

            let content = buildContent(for: schedule, services: services, liveMetrics: liveMetrics)
            let trigger = buildTrigger(for: schedule.scheduleType)

            let request = UNNotificationRequest(
                identifier: "summary-\(schedule.id.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    // MARK: - Content building

    private func buildContent(for schedule: MetricSummarySchedule,
                              services: [Service],
                              liveMetrics: [UUID: [ServiceMetric]]) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        guard let service = services.first(where: { $0.id == schedule.serviceID }) else {
            content.title = schedule.serviceName
            content.body = "No data available."
            return content
        }

        let allMetrics = liveMetrics[service.id] ?? []
        let metricsToShow: [ServiceMetric]
        if schedule.metricLabels.isEmpty {
            metricsToShow = Array(allMetrics.prefix(5))
        } else {
            metricsToShow = allMetrics.filter { schedule.metricLabels.contains($0.label) }
        }

        content.title = service.name
        content.sound = .default

        if metricsToShow.isEmpty {
            content.body = "Tap to check current status."
        } else {
            content.body = metricsToShow.map { "\($0.label): \($0.value)" }.joined(separator: " | ")
        }

        // Badge with alert count
        let alertCount = allMetrics.filter(\.isAlert).count
        if alertCount > 0 {
            content.badge = alertCount as NSNumber
            content.interruptionLevel = .timeSensitive
        } else {
            content.interruptionLevel = .passive
        }

        return content
    }

    // MARK: - Trigger building

    private func buildTrigger(for type: MetricSummarySchedule.ScheduleType) -> UNNotificationTrigger {
        switch type {
        case .daily(let hour, let minute):
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .interval(let hours):
            return UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(hours * 3600),
                repeats: true
            )
        }
    }
}
