import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.vibeslol.app"

    private init() {}

    // MARK: - Keys

    private enum Key: String {
        case userId = "vibeslol_user_id"
        case deviceToken = "vibeslol_device_token"
        case username = "vibeslol_username"
        case accessToken = "vibeslol_access_token"
        case refreshToken = "vibeslol_refresh_token"
    }

    // MARK: - Public API

    var userId: String? {
        get { read(key: .userId) }
        set { save(key: .userId, value: newValue) }
    }

    var deviceToken: String? {
        get { read(key: .deviceToken) }
        set { save(key: .deviceToken, value: newValue) }
    }

    var username: String? {
        get { read(key: .username) }
        set { save(key: .username, value: newValue) }
    }

    var accessToken: String? {
        get { read(key: .accessToken) }
        set { save(key: .accessToken, value: newValue) }
    }

    var refreshToken: String? {
        get { read(key: .refreshToken) }
        set { save(key: .refreshToken, value: newValue) }
    }

    var isLoggedIn: Bool {
        userId != nil
    }

    func clear() {
        userId = nil
        deviceToken = nil
        username = nil
        accessToken = nil
        refreshToken = nil
    }

    // MARK: - Keychain Operations

    private func save(key: Key, value: String?) {
        let account = key.rawValue

        // Always delete existing first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // If value is nil, we just wanted to delete
        guard let value = value, let data = value.data(using: .utf8) else { return }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func read(key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
