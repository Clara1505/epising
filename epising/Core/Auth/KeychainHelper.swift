//
//  KeychainHelper.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation

// Stockage sécurisé du device ID (anti-fraude NFC)
enum KeychainHelper {

    static let deviceIdKey = "epising.deviceId"

    // Retourne le device ID existant ou en crée un nouveau
    static func getOrCreateDeviceId() -> String {
        if let existing = read(key: deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        save(key: deviceIdKey, value: newId)
        return newId
    }

    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
