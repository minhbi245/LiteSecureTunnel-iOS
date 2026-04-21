//
//  KeychainStore.swift
//  LiteSecureTunnel-iOS
//
//  Created by Leo Nguyen on 20/4/26.
//

import Foundation
import Security

enum KeychainError: Error {
    case status(OSStatus)
    case unexpectedData
}

struct KeychainStore {
    static let service = "com.leonguyen.LiteSecureTunnel-iOS"
    static let account = "wg-private-key"
    static let accessGroup = "2BWXQ8ACBB.com.leonguyen.LiteSecureTunnel-iOS"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup
        ]
    }

    static func save(_ data: Data) throws {
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attrs: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
            if updateStatus != errSecSuccess { throw KeychainError.status(updateStatus) }
        default:
            throw KeychainError.status(status)
        }
    }

    static func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeychainError.unexpectedData }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.status(status)
        }
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.status(status)
        }
    }
}
