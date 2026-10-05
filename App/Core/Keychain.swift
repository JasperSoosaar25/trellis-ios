import Foundation
import Security

enum Keychain {
    static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.trellis.client", kSecAttrAccount as String: "token",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func write(_ token: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.trellis.client", kSecAttrAccount as String: "token"]
        let values: [String: Any] = [kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let update = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        let status = update == errSecItemNotFound ? SecItemAdd(query.merging(values) { _, b in b } as CFDictionary, nil) : update
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Secure token storage failed (\(status))."]) }
    }
    static func delete() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.trellis.client", kSecAttrAccount as String: "token"] as CFDictionary)
    }
}
