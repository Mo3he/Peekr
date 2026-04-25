import Foundation

/// A single recorded reading of a metric at a point in time.
struct MetricSnapshot: Identifiable, Codable {
    var id: UUID = UUID()
    var value: String
    var isAlert: Bool
    var timestamp: Date
}

/// Stores the last N readings per service+metric key.
/// Keys are formatted as "\(serviceID.uuidString)|\(label.lowercased())".
/// Persisted to UserDefaults so history survives short app restarts.
@MainActor
final class MetricHistoryStore {
    static let shared = MetricHistoryStore()
    private init() { load() }

    private let storageKey = "peekr.metricHistory"
    private let maxPerMetric = 50

    private var history: [String: [MetricSnapshot]] = [:]

    // MARK: - Writing

    func record(serviceID: UUID, metrics: [ServiceMetric]) {
        let now = Date()
        var dirty = false
        for m in metrics {
            let key = "\(serviceID.uuidString)|\(m.label.lowercased())"
            var snaps = history[key, default: []]
            // Debounce: skip if same value recorded < 5 seconds ago
            if let last = snaps.last, last.value == m.value,
               now.timeIntervalSince(last.timestamp) < 5 { continue }
            snaps.append(MetricSnapshot(value: m.value, isAlert: m.isAlert, timestamp: now))
            if snaps.count > maxPerMetric { snaps.removeFirst(snaps.count - maxPerMetric) }
            history[key] = snaps
            dirty = true
        }
        if dirty { save() }
    }

    // MARK: - Reading

    func snapshots(serviceID: UUID, label: String) -> [MetricSnapshot] {
        history["\(serviceID.uuidString)|\(label.lowercased())"] ?? []
    }

    // MARK: - Cleanup

    func remove(serviceID: UUID) {
        let prefix = serviceID.uuidString
        history = history.filter { !$0.key.hasPrefix(prefix) }
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: [MetricSnapshot]].self, from: data)
        else { return }
        history = decoded
    }
}
