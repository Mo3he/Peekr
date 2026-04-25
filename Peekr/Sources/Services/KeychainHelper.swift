import Foundation
import Security
import os.log

enum KeychainHelper {
    // Stable service identifier - never change this or existing items become unreachable.
    private static let service = "com.mblieden.peekr"
    private static let log = Logger(subsystem: "com.mblieden.peekr", category: "Keychain")

    static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let search: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemUpdate(search as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = search
            add[kSecValueData as String]      = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            if addStatus != errSecSuccess {
                log.error("SecItemAdd failed for account=\(account, privacy: .public) status=\(addStatus)")
            }
        } else if status != errSecSuccess {
            log.error("SecItemUpdate failed for account=\(account, privacy: .public) status=\(status)")
        }
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String:  kSecMatchLimitOne,
            kSecReturnData as String:  true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        // errSecItemNotFound is normal (no credential set yet); other failures are not.
        if status != errSecSuccess && status != errSecItemNotFound {
            log.error("SecItemCopyMatching failed for account=\(account, privacy: .public) status=\(status)")
        }
        return nil
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            log.error("SecItemDelete failed for account=\(account, privacy: .public) status=\(status)")
        }
    }
}
