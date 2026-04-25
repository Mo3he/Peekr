import Foundation
import Combine

/// Single source of truth for the in-app status event log. Decoupled from HomeViewModel
/// so that BackgroundRefreshCoordinator can record transitions when the app is woken
/// in the background — without those, push notifications would fire but the in-app
/// "Status Log" tab would stay empty.
@MainActor
final class StatusEventStore: ObservableObject {
    static let shared = StatusEventStore()

    @Published private(set) var events: [StatusEvent] = []

    private let storageKey = "peekr.statusEvents"
    private let maxEvents = 200

    private init() { load() }

    /// Records a transition. No-op when the transition is meaningless (no change,
    /// from .unknown, or from .checking — the latter two are seed states, not real
    /// "the service moved offline" events).
    func recordTransition(previousStatus old: ServiceStatus,
                          newStatus new: ServiceStatus,
                          service: Service) {
        guard old != new, old != .unknown, old != .checking else { return }
        let event = StatusEvent(
            serviceID: service.id,
            serviceName: service.name,
            oldStatus: old,
            newStatus: new
        )
        events.insert(event, at: 0)
        if events.count > maxEvents { events = Array(events.prefix(maxEvents)) }
        save()
    }

    func clear() {
        events.removeAll()
        save()
    }

    /// DEMO: append a fully-formed event (used by `DemoMode` only).
    func appendDemo(_ event: StatusEvent) {
        events.append(event)
        events.sort { $0.timestamp > $1.timestamp }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StatusEvent].self, from: data)
        else { return }
        events = decoded
    }
}
