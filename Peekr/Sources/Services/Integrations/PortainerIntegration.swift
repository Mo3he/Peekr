import SwiftUI

struct PortainerIntegration: ServiceIntegration {
    func fetchMetrics(service: Service) async throws -> [ServiceMetric] {
        guard let token = service.apiKey, !token.isEmpty else {
            return [ServiceMetric(label: "API key required", value: "Swipe → Edit", icon: "key.fill", color: .orange)]
        }
        let base = baseURL(service)
        let headers = ["X-API-Key": token]

        guard let endpointsURL = URL(string: "\(base)/api/endpoints") else { throw IntegrationError.badURL }
        let json = try await fetchJSON(url: endpointsURL, headers: headers)
        guard let endpoints = json as? [[String: Any]] else { throw IntegrationError.unexpectedFormat }

        var metrics: [ServiceMetric] = []
        metrics.append(ServiceMetric(label: "Environments", value: "\(endpoints.count)", icon: "server.rack", color: .primary))

        // Fetch containers for each endpoint (first 3)
        var running = 0, stopped = 0
        for ep in endpoints {
            guard let epID = ep["Id"] as? Int,
                  let url = URL(string: "\(base)/api/endpoints/\(epID)/docker/containers/json?all=true") else { continue }
            if let containers = try? await fetchJSON(url: url, headers: headers) as? [[String: Any]] {
                running += containers.filter { ($0["State"] as? String) == "running" }.count
                stopped += containers.filter { ($0["State"] as? String) != "running" }.count
            }
        }
        if running + stopped > 0 {
            metrics.append(ServiceMetric(label: "Running", value: "\(running)", icon: "play.circle.fill", color: .green))
            if stopped > 0 {
                metrics.append(ServiceMetric(label: "Stopped", value: "\(stopped)", icon: "stop.circle.fill", color: .red, isAlert: true))
            }
        }
        return metrics
    }
}
