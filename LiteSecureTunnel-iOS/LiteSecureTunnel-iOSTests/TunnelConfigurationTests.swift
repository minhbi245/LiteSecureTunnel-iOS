//
//  TunnelConfigurationTests.swift
//  LiteSecureTunnel-iOSTests
//
//  Created by Leo Nguyen on 21/4/26.
//

import XCTest
@testable import LiteSecureTunnel_iOS

final class TunnelConfigurationTests: XCTestCase {

    func test_codable_roundtrip_preservesValues() throws {
        let original = TunnelConfiguration(
            interfaceAddress: "10.8.0.2/24",
            dnsServers: ["1.1.1.1", "8.8.8.8"],
            peerPublicKey: "***REMOVED***",
            peerEndpoint: "192.168.1.8:51820",
            allowedIPs: ["0.0.0.0/0", "::/0"],
            presharedKey: "***REMOVED***"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TunnelConfiguration.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func test_codable_handlesNilPresharedKey() throws {
        let config = TunnelConfiguration(
            interfaceAddress: "10.8.0.2/24",
            dnsServers: ["1.1.1.1"],
            peerPublicKey: "pubkey",
            peerEndpoint: "host:51820",
            allowedIPs: ["0.0.0.0/0"],
            presharedKey: nil
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TunnelConfiguration.self, from: data)

        XCTAssertNil(decoded.presharedKey)
    }
}
