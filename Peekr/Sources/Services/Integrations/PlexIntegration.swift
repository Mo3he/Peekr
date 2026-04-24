import SwiftUI

struct PlexIntegration: ServiceIntegration {
    func fetchMetrics(service: Service) async throws -> [ServiceMetric] {
        guard let token = service.apiKey, !token.isEmpty else {
            return [ServiceMetric(label: "Token required", value: "Swipe → Edit", icon: "key.fill", color: .orange)]
        }
        let base = baseURL(service)
        let headers = ["X-Plex-Token": token, "Accept": "application/json"]

        async let serverResult   = fetchJSON(url: URL(string: "\(base)/")!, headers: headers)
        async let sessionsResult = fetchJSON(url: URL(string: "\(base)/status/sessions")!, headers: headers)

        var metrics: [ServiceMetric] = []

        if let root = try? await serverResult as? [String: Any],
           let ms = root["MediaContainer"] as? [String: Any] {
            if let version = ms["version"] as? String {
                metrics.append(ServiceMetric(label: "Version", value: version, icon: "tag.fill", color: .secondary))
            }
        }

        if let root = try? await sessionsResult as? [String: Any],
           let ms = root["MediaContainer"] as? [String: Any] {
            let size = ms["size"] as? Int ?? 0
            metrics.append(ServiceMetric(
                label: "Active streams",
                value: "\(size)",
                icon: "play.fill",
                color: size == 0 ? .secondary : .green
            ))
        }

        return metrics
    }
}
