import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let service = "com.hone.app"

    // MARK: - Provider API Keys

    func save(_ key: String, for provider: AIProvider) {
        guard let data = key.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  provider.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    func load(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  provider.keychainAccount,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8),
           !key.isEmpty {
            return key
        }
        // Fall back to built-in key for the default provider (FG Version only)
        if provider == .anthropic, let builtIn = Config.builtInAPIKey {
            return builtIn
        }
        return nil
    }

    func delete(for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  provider.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Legacy (Anthropic-only) shim — keeps old saves readable

    func save(_ key: String) {
        save(key, for: .anthropic)
    }

    func load() -> String? {
        // Try new key first, fall back to old account name for existing installs
        if let key = load(for: .anthropic) { return key }
        return loadLegacy()
    }

    private func loadLegacy() -> String? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  "anthropic-api-key",
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else { return nil }
        return key
    }
}
