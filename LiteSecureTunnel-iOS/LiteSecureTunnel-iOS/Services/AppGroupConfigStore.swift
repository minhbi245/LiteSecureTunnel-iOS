//
//  AppGroupConfigStore.swift
//  LiteSecureTunnel-iOS
//
//  Created by Leo Nguyen on 20/4/26.
//

import Foundation

struct AppGroupConfigStore {
    static let suiteName = "group.com.leonguyen.LiteSecureTunnel-iOS"
    static let configKey = "tunnel.configuration"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func save(_ config: TunnelConfiguration) throws {
        let data = try JSONEncoder().encode(config)
        defaults?.set(data, forKey: configKey)
    }

    static func load() -> TunnelConfiguration? {
        guard let data = defaults?.data(forKey: configKey) else { return nil }
        return try? JSONDecoder().decode(TunnelConfiguration.self, from: data)
    }

    static func delete() {
        defaults?.removeObject(forKey: configKey)
    }
}
