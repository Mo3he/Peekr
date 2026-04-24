import SwiftUI

struct GitHubIntegration: ServiceIntegration {
    private let apiBase = "https://api.github.com"

    func fetchMetrics(service: Service) async throws -> [ServiceMetric] {
        var headers: [String: String] = ["Accept": "application/vnd.github.v3+json"]
        if let token = service.apiKey, !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        }

        var metrics: [ServiceMetric] = []

        // Rate limit works with or without auth
        if let url = URL(string: "\(apiBase)/rate_limit"),
           let json = try? await fetchJSON(url: url, headers: headers) as? [String: Any],
           let rate = json["rate"] as? [String: Any],
           let remaining = rate["remaining"] as? Int,
           let limit = rate["limit"] as? Int {
            let pct = limit > 0 ? Double(remaining) / Double(limit) * 100 : 100
            metrics.append(ServiceMetric(
                label: "Rate limit",
                value: "\(remaining) / \(limit)",
                icon: "gauge.medium",
                color: pct < 20 ? .red : pct < 50 ? .orange : .green,
                isAlert: remaining < 10
            ))
        }

        // Authenticated user info
        if let token = service.apiKey, !token.isEmpty,
           let url = URL(string: "\(apiBase)/user"),
           let user = try? await fetchJSON(url: url, headers: headers) as? [String: Any],
           let login = user["login"] as? String {
            metrics.append(ServiceMetric(
                label: "Signed in as",
                value: "@\(login)",
                icon: "person.fill",
                color: .primary
            ))
            if let repos = user["public_repos"] as? Int {
                metrics.append(ServiceMetric(
                    label: "Public repos",
                    value: "\(repos)",
                    icon: "folder.fill",
                    color: .secondary
                ))
            }
        }

        return metrics
    }
}
