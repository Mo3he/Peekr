import Foundation

/// Records recent status check results per service for sparkline display.
struct StatusSnapshot: Identifiable, Codable {
    var id: Date { timestamp }
    var latencyMs: Double?
    var status: ServiceStatus
    var timestamp: Date
}

/// Stores the last N snapshots per service in UserDefaults.
@MainActor
final class StatusHistoryStore {
    static let shared = StatusHistoryStore()
    private init() { load() }

    private let key = "peekr.statusHistory"
    private let maxPerService = 30

    private(set) var history: [UUID: [StatusSnapshot]] = [:]

    func record(serviceID: UUID, status: ServiceStatus, latencyMs: Double?) {
        let snap = StatusSnapshot(latencyMs: latencyMs, status: status, timestamp: Date())
        var snaps = history[serviceID, default: []]
        snaps.append(snap)
        if snaps.count > maxPerService { snaps.removeFirst(snaps.count - maxPerService) }
        history[serviceID] = snaps
        save()
    }

    func snapshots(for serviceID: UUID) -> [StatusSnapshot] {
        history[serviceID, default: []]
    }

    func remove(serviceID: UUID) {
        history.removeValue(forKey: serviceID)
        save()
    }

    private func save() {
        // Convert UUID keys to strings for Codable
        let encoded = Dictionary(uniqueKeysWithValues: history.map { ($0.key.uuidString, $0.value) })
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [StatusSnapshot]].self, from: data)
        else { return }
        history = Dictionary(uniqueKeysWithValues: decoded.compactMap { k, v in
            UUID(uuidString: k).map { ($0, v) }
        })
    }
}
