import Foundation
import Security

/// Persists service metadata to UserDefaults. Credentials are stored in the Keychain.
/// NOTE: iCloud sync requires a paid Apple Developer account (com.apple.developer.ubiquity-kvstore-identifier
/// entitlement). Re-enable by adding that entitlement and the NSUbiquitousKeyValueStore calls below.
@MainActor
final class ServiceStore: ObservableObject {
    static let shared = ServiceStore()

    @Published private(set) var services: [Service] = []

    private let key = "peekr.services.v3"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        load()
    }

    func add(_ service: Service) {
        services.append(service)
        save()
    }

    func remove(at offsets: IndexSet) {
        for idx in offsets { deleteCredentials(for: services[idx].id) }
        services.remove(atOffsets: offsets)
        save()
    }

    func remove(id: UUID) {
        deleteCredentials(for: id)
        services.removeAll { $0.id == id }
        save()
    }

    func update(_ service: Service) {
        guard let idx = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[idx] = service
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        services.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Persistence

    private func save() {
        // Strip credentials before writing to UserDefaults; push them to Keychain instead.
        let sanitized = services.map { s -> Service in
            saveCredentials(for: s)
            var copy = s
            copy.apiKey   = nil
            copy.username = nil
            copy.password = nil
            return copy
        }
        guard let data = try? encoder.encode(sanitized) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? decoder.decode([Service].self, from: data)
        else {
            services = Self.sampleServices
            return
        }
        // Restore credentials from Keychain, falling back to any value still in UserDefaults JSON
        // (migration path for users upgrading from a build that stored credentials in UserDefaults).
        services = decoded.map { s in
            var copy = s
            copy.apiKey   = KeychainHelper.load(account: keychainKey("apikey",    id: s.id))
                         ?? legacyKeychainLoad(account: keychainKey("apikey",    id: s.id))
                         ?? s.apiKey
            copy.username = KeychainHelper.load(account: keychainKey("username",  id: s.id))
                         ?? legacyKeychainLoad(account: keychainKey("username",  id: s.id))
                         ?? s.username
            copy.password = KeychainHelper.load(account: keychainKey("password",  id: s.id))
                         ?? legacyKeychainLoad(account: keychainKey("password",  id: s.id))
                         ?? s.password
            return copy
        }
        // Persist immediately so any migrated credentials land in the new Keychain format
        // and are removed from UserDefaults.
        save()
    }

    /// Reads keychain items stored by older builds that did not set kSecAttrService.
    private func legacyKeychainLoad(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String:  kSecMatchLimitOne,
            kSecReturnData as String:  true
        ]
        var result: AnyObject?
        guard Security.SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Keychain helpers

    private func keychainKey(_ field: String, id: UUID) -> String {
        "peekr.\(field).\(id.uuidString)"
    }

    private func saveCredentials(for service: Service) {
        let id = service.id
        if let v = service.apiKey,   !v.isEmpty { KeychainHelper.save(v, account: keychainKey("apikey",   id: id)) }
        else                                    { KeychainHelper.delete(account: keychainKey("apikey",    id: id)) }
        if let v = service.username, !v.isEmpty { KeychainHelper.save(v, account: keychainKey("username", id: id)) }
        else                                    { KeychainHelper.delete(account: keychainKey("username",  id: id)) }
        if let v = service.password, !v.isEmpty { KeychainHelper.save(v, account: keychainKey("password", id: id)) }
        else                                    { KeychainHelper.delete(account: keychainKey("password",  id: id)) }
    }

    private func deleteCredentials(for id: UUID) {
        KeychainHelper.delete(account: keychainKey("apikey",   id: id))
        KeychainHelper.delete(account: keychainKey("username", id: id))
        KeychainHelper.delete(account: keychainKey("password", id: id))
    }

    private static let sampleServices: [Service] = []
}
