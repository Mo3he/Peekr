import SwiftUI

private enum SynologyAuthError: Error {
    case otpRequired
    case otpInvalid
}

private let synologySessionPrefix = "synology-session-"
private let synologyDevicePrefix  = "synology-device-"

struct SynologyIntegration: ServiceIntegration {

    func fetchMetrics(service: Service) async throws -> [ServiceMetric] {
        guard let username = service.username, !username.isEmpty,
              let password = service.password, !password.isEmpty else {
            return [ServiceMetric(label: "Credentials required", value: "Swipe \u{2192} Edit", icon: "key.fill", color: .orange)]
        }
        return try await fetchWithAutoReauth(service: service, username: username, password: password)
    }

    // MARK: - Auto-reauth

    private func fetchWithAutoReauth(service: Service, username: String, password: String) async throws -> [ServiceMetric] {
        let sidKey = synologySessionPrefix + service.id.uuidString
        do {
            let sid = try await resolveSID(service: service, username: username, password: password, sidKey: sidKey, forceRefresh: false)
            let result = try await fetchWithSID(service: service, sid: sid)
            if result.count == 1, result[0].icon == "lock.rotation" {
                let fresh = try await resolveSID(service: service, username: username, password: password, sidKey: sidKey, forceRefresh: true)
                return try await fetchWithSID(service: service, sid: fresh)
            }
            return result
        } catch SynologyAuthError.otpRequired {
            return [ServiceMetric(label: "One-Time Code needed", value: "Swipe \u{2192} Edit to add current OTP", icon: "lock.fill", color: .orange, isAlert: true)]
        } catch SynologyAuthError.otpInvalid {
            return [ServiceMetric(label: "OTP incorrect or expired", value: "Enter a fresh code in Edit", icon: "lock.slash.fill", color: .red, isAlert: true)]
        } catch IntegrationError.authFailed {
            KeychainHelper.save("", account: sidKey)
            return [ServiceMetric(label: "Auth failed", value: "Check credentials in Edit", icon: "exclamationmark.lock.fill", color: .red, isAlert: true)]
        }
    }

    private func resolveSID(service: Service, username: String, password: String, sidKey: String, forceRefresh: Bool) async throws -> String {
        if !forceRefresh, let cached = KeychainHelper.load(account: sidKey), !cached.isEmpty {
            return cached
        }
        let sid = try await authenticate(service: service, username: username, password: password)
        KeychainHelper.save(sid, account: sidKey)
        return sid
    }

    // MARK: - Authentication

    /// Logs in to DSM and returns a session ID.
    ///
    /// Flow:
    /// 1. Try with cached trusted device ID (bypasses OTP on repeat logins).
    /// 2. If DSM says OTP is required (error 403) and the user has an OTP in apiKey,
    ///    retry including the OTP code + device_name so DSM issues a new trusted device ID.
    /// 3. Store the returned `did` (device ID) in Keychain for future logins.
    private func authenticate(service: Service, username: String, password: String) async throws -> String {
        let base = baseURL(service)
        let deviceKey      = synologyDevicePrefix + service.id.uuidString
        let cachedDeviceId = KeychainHelper.load(account: deviceKey) ?? ""

        let sid = try await attemptLogin(
            base: base,
            username: username,
            password: password,
            otp: nil,
            deviceId: cachedDeviceId.isEmpty ? nil : cachedDeviceId,
            service: service
        )
        return sid
    }

    private func attemptLogin(base: String, username: String, password: String, otp: String?, deviceId: String?, service: Service) async throws -> String {
        guard let url = URL(string: "\(base)/webapi/auth.cgi") else { throw IntegrationError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8

        var items: [URLQueryItem] = [
            URLQueryItem(name: "api",         value: "SYNO.API.Auth"),
            URLQueryItem(name: "version",     value: "6"),
            URLQueryItem(name: "method",      value: "login"),
            URLQueryItem(name: "account",     value: username),
            URLQueryItem(name: "passwd",      value: password),
            URLQueryItem(name: "session",     value: "HSM"),
            URLQueryItem(name: "format",      value: "sid"),
            URLQueryItem(name: "device_name", value: "HSM")
        ]
        if let did = deviceId, !did.isEmpty {
            items.append(URLQueryItem(name: "device_id", value: did))
        }
        if let code = otp, !code.isEmpty {
            items.append(URLQueryItem(name: "otp_code", value: code))
        }
        var bodyComps = URLComponents()
        bodyComps.queryItems = items
        req.httpBody = bodyComps.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await IntegrationHTTP.session.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IntegrationError.unexpectedFormat
        }

        if let success = json["success"] as? Bool, success,
           let sid = (json["data"] as? [String: Any])?["sid"] as? String, !sid.isEmpty {
            // Cache trusted device ID if DSM issued one
            if let did = (json["data"] as? [String: Any])?["did"] as? String, !did.isEmpty {
                let deviceKey = synologyDevicePrefix + service.id.uuidString
                KeychainHelper.save(did, account: deviceKey)
            }
            return sid
        }

        guard let code = (json["error"] as? [String: Any])?["code"] as? Int else {
            throw IntegrationError.authFailed
        }

        switch code {
        case 403:
            // OTP required - retry with user-supplied code if available
            if otp == nil, let userOTP = service.apiKey, !userOTP.isEmpty {
                return try await attemptLogin(base: base, username: username, password: password, otp: userOTP, deviceId: nil, service: service)
            }
            throw SynologyAuthError.otpRequired
        case 404, 406:
            throw SynologyAuthError.otpInvalid
        case 400, 401, 402:
            throw IntegrationError.authFailed
        default:
            throw IntegrationError.authFailed
        }
    }

    // MARK: - Metrics

    private func fetchWithSID(service: Service, sid: String) async throws -> [ServiceMetric] {
        let base = baseURL(service)
        func entry(_ api: String, _ version: String, _ method: String) -> URL? {
            var c = URLComponents(string: "\(base)/webapi/entry.cgi")
            c?.queryItems = [
                URLQueryItem(name: "api",     value: api),
                URLQueryItem(name: "version", value: version),
                URLQueryItem(name: "method",  value: method),
                URLQueryItem(name: "_sid",    value: sid)
            ]
            return c?.url
        }

        guard let infoURL    = entry("SYNO.DSM.Info",                "2", "getinfo"),
              let utilURL    = entry("SYNO.Core.System.Utilization", "1", "get"),
              let storageURL = entry("SYNO.Storage.CGI.Storage",     "1", "load_info"),
              let hddURL     = entry("SYNO.Storage.CGI.HDD",         "1", "list") else {
            throw IntegrationError.badURL
        }

        async let infoResult    = fetchJSON(url: infoURL)
        async let utilResult    = fetchJSON(url: utilURL)
        async let storageResult = fetchJSON(url: storageURL)
        async let hddResult     = fetchJSON(url: hddURL)

        var metrics: [ServiceMetric] = []

        // --- System info ---
        if let info = try? await infoResult as? [String: Any] {
            if let code = (info["error"] as? [String: Any])?["code"] as? Int,
               [105, 106, 107, 119].contains(code) {
                return [ServiceMetric(label: "Session expired", value: "Re-authenticating...", icon: "lock.rotation", color: .orange, isAlert: true)]
            }
            if let data = info["data"] as? [String: Any] {
                let version = data["productversion"] as? String ?? data["version"] as? String ?? ""
                if !version.isEmpty {
                    metrics.append(ServiceMetric(label: "DSM", value: version, icon: "tag.fill", color: .secondary))
                }
                if let uptime = data["uptime"] as? Int {
                    metrics.append(ServiceMetric(label: "Uptime", value: formatUptime(uptime), icon: "clock.fill", color: .secondary))
                }
            }
        }

        // --- CPU & RAM ---
        if let util = try? await utilResult as? [String: Any],
           let data = util["data"] as? [String: Any] {
            if let cpu = data["cpu"] as? [String: Any] {
                let user   = cpu["user_load"]   as? Int ?? 0
                let system = cpu["system_load"] as? Int ?? 0
                let pct    = user + system
                let color: Color = pct > 80 ? .red : pct > 60 ? .orange : .primary
                metrics.append(ServiceMetric(label: "CPU", value: "\(pct)%", icon: "cpu", color: color, isAlert: pct > 80))
            }
            if let mem = data["memory"] as? [String: Any] {
                let pct = mem["real_usage"] as? Int ?? (mem["real_usage"] as? String).flatMap(Int.init) ?? -1
                if pct >= 0 {
                    let color: Color = pct > 85 ? .orange : .primary
                    metrics.append(ServiceMetric(label: "RAM", value: "\(pct)%", icon: "memorychip", color: color, isAlert: pct > 90))
                }
            }
        }

        // --- Volumes ---
        if let storage = try? await storageResult as? [String: Any],
           let data    = storage["data"] as? [String: Any],
           let volumes = data["vol_info"] as? [[String: Any]] {
            let healthy = volumes.filter { ($0["status"] as? String)?.lowercased() == "normal" }
            let volColor: Color = healthy.count == volumes.count ? .green : .red
            metrics.append(ServiceMetric(
                label: "Volumes",
                value: "\(healthy.count)/\(volumes.count) healthy",
                icon: "externaldrive.fill",
                color: volColor,
                isAlert: healthy.count < volumes.count
            ))
            for vol in volumes {
                let name     = vol["name"] as? String ?? ""
                let freeInt  = (vol["free_size"]  as? Int) ?? (vol["free_size"]  as? String).flatMap(Int.init) ?? 0
                let totalInt = (vol["total_size"] as? Int) ?? (vol["total_size"] as? String).flatMap(Int.init) ?? 0
                guard totalInt > 0, !name.isEmpty else { continue }
                let pctUsed   = Double(totalInt - freeInt) / Double(totalInt)
                let freeColor: Color = pctUsed >= 0.9 ? .red : pctUsed >= 0.75 ? .orange : .green
                metrics.append(ServiceMetric(
                    label: name,
                    value: "\(formatBytes(freeInt)) free",
                    icon: "internaldrive",
                    color: freeColor,
                    isAlert: pctUsed >= 0.9
                ))
            }
        }

        // --- Disk SMART ---
        if let hdd  = try? await hddResult as? [String: Any],
           let data  = hdd["data"] as? [String: Any],
           let disks = data["list"] as? [[String: Any]] {
            let bad = disks.filter {
                let s = ($0["smart_status"] as? String ?? "").lowercased()
                return s == "failure" || s == "warning"
            }
            if !bad.isEmpty {
                metrics.append(ServiceMetric(
                    label: "Disk SMART",
                    value: "\(bad.count) disk(s) need attention",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    isAlert: true
                ))
            } else if !disks.isEmpty {
                metrics.append(ServiceMetric(label: "Disk SMART", value: "All normal", icon: "checkmark.circle.fill", color: .green))
            }
        }

        return metrics
    }

    // MARK: - Helpers

    private func formatUptime(_ seconds: Int) -> String {
        let d = seconds / 86400
        let h = (seconds % 86400) / 3600
        if d > 0 { return "\(d)d \(h)h" }
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func formatBytes(_ bytes: Int) -> String {
        let b = Double(bytes)
        if b >= 1_099_511_627_776 { return String(format: "%.1f TB", b / 1_099_511_627_776) }
        if b >= 1_073_741_824    { return String(format: "%.1f GB", b / 1_073_741_824) }
        if b >= 1_048_576        { return String(format: "%.0f MB", b / 1_048_576) }
        return String(format: "%.0f KB", b / 1_024)
    }
}
