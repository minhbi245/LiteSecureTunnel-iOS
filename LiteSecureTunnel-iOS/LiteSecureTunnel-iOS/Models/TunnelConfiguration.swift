//
//  TunnelConfiguration.swift
//  LiteSecureTunnel-iOS
//
//  Created by Leo Nguyen on 20/4/26.
//

import Foundation

nonisolated struct TunnelConfiguration: Codable, Equatable, Sendable {
    var interfaceAddress: String
    var dnsServers: [String]
    var peerPublicKey: String
    var peerEndpoint: String
    var allowedIPs: [String]
    var presharedKey: String?
}
