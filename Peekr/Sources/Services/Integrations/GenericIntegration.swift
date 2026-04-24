import SwiftUI

struct GenericIntegration: ServiceIntegration {
    func fetchMetrics(service: Service) async throws -> [ServiceMetric] {
        // For services without a specific integration, just return HTTP status
        guard let url = service.url else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        let (_, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        return [ServiceMetric(
            label: "HTTP Status",
            value: "\(code)",
            icon: code < 400 ? "checkmark.circle.fill" : "xmark.circle.fill",
            color: code < 400 ? .green : .red
        )]
    }
}

enum IntegrationError: LocalizedError {
    case badURL, unexpectedFormat, authFailed

    var errorDescription: String? {
        switch self {
        case .badURL:            return "Invalid URL"
        case .unexpectedFormat:  return "Unexpected API response"
        case .authFailed:        return "Authentication failed"
        }
    }
}
