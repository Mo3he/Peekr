import Foundation

/// Stores per-metric alert rules and tracks previously-seen state to avoid duplicate notifications.
final class MetricAlertStore {
    static let shared = MetricAlertStore()
    private init() { load() }

    enum Condition: String, Codable, CaseIterable {
        case whenAlert        // notify when metric.isAlert becomes true
        case whenValueChanges // notify when metric.value string changes
    }

    private let rulesKey      = "peekr.metricAlertRules"
    private let lastValuesKey = "peekr.metricLastValues"
    private let lastAlertKey  = "peekr.metricLastAlertState"

    // "serviceID:label" -> condition
    private(set) var rules: [String: Condition] = [:]
    // "serviceID:label" -> last seen value (for whenValueChanges dedup)
    private var lastValues: [String: String] = [:]
    // "serviceID:label" -> last isAlert state we acted on (for whenAlert dedup)
    private var lastAlertState: [String: Bool] = [:]

    private func ruleKey(_ serviceID: UUID, _ label: String) -> String {
        "\(serviceID.uuidString):\(label)"
    }

    func hasRule(serviceID: UUID, label: String) -> Bool {
        rules[ruleKey(serviceID, label)] != nil
    }

    func rule(serviceID: UUID, label: String) -> Condition? {
        rules[ruleKey(serviceID, label)]
    }

    func setRule(_ condition: Condition, serviceID: UUID, label: String) {
        rules[ruleKey(serviceID, label)] = condition
        save()
    }

    func removeRule(serviceID: UUID, label: String) {
        let k = ruleKey(serviceID, label)
        rules.removeValue(forKey: k)
        lastValues.removeValue(forKey: k)
        lastAlertState.removeValue(forKey: k)
        save()
    }

    func removeAllRules(for serviceID: UUID) {
        let prefix = serviceID.uuidString + ":"
        rules          = rules.filter          { !$0.key.hasPrefix(prefix) }
        lastValues     = lastValues.filter     { !$0.key.hasPrefix(prefix) }
        lastAlertState = lastAlertState.filter { !$0.key.hasPrefix(prefix) }
        save()
    }

    /// Returns true if a notification should fire for this metric right now.
    /// Mutates internal state to prevent duplicate notifications.
    func shouldFire(metric: ServiceMetric, serviceID: UUID) -> Bool {
        let k = ruleKey(serviceID, metric.label)
        guard let condition = rules[k] else { return false }

        switch condition {
        case .whenAlert:
            let wasAlert = lastAlertState[k] ?? false
            if metric.isAlert && !wasAlert {
                lastAlertState[k] = true
                saveLastState()
                return true
            }
            if !metric.isAlert && wasAlert {
                lastAlertState[k] = false
                saveLastState()
            }
            return false

        case .whenValueChanges:
            let prev = lastValues[k]
            lastValues[k] = metric.value
            saveLastValues()
            // Only fire after we have seen at least one previous value
            return prev != nil && prev != metric.value
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(rules.mapValues(\.rawValue)) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
        saveLastValues()
        saveLastState()
    }

    private func saveLastValues() {
        if let data = try? JSONEncoder().encode(lastValues) {
            UserDefaults.standard.set(data, forKey: lastValuesKey)
        }
    }

    private func saveLastState() {
        if let data = try? JSONEncoder().encode(lastAlertState) {
            UserDefaults.standard.set(data, forKey: lastAlertKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            rules = dict.compactMapValues { Condition(rawValue: $0) }
        }
        if let data = UserDefaults.standard.data(forKey: lastValuesKey),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            lastValues = dict
        }
        if let data = UserDefaults.standard.data(forKey: lastAlertKey),
           let dict = try? JSONDecoder().decode([String: Bool].self, from: data) {
            lastAlertState = dict
        }
    }
}
