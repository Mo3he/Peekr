import Foundation

/// A user-configured summary notification for one service.
struct MetricSummarySchedule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var serviceID: UUID
    var serviceName: String
    /// Metric labels to include. Empty = include all visible metrics.
    var metricLabels: [String]
    var scheduleType: ScheduleType
    var isEnabled: Bool = true

    enum ScheduleType: Codable, Equatable, Hashable {
        case daily(hour: Int, minute: Int)
        case interval(hours: Int)

        var displayName: String {
            switch self {
            case .daily(let h, let m):
                let date = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
                return "Daily at " + date.formatted(date: .omitted, time: .shortened)
            case .interval(let h):
                return h == 1 ? "Every hour" : "Every \(h) hours"
            }
        }
    }
}
