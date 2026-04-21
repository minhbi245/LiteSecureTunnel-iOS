//
//  VPNManager.swift
//  LiteSecureTunnel-iOS
//
//  Created by Leo Nguyen on 20/4/26.
//

import Foundation
import NetworkExtension
import Combine

enum VPNError: Error {
    case permissionDenied
    case configurationInvalid
    case notConfigured
    case underlying(Error)
}

@MainActor
final class VPNManager: ObservableObject {
    static let extensionBundleID = "com.leonguyen.LiteSecureTunnel-iOS.PacketTunnel"

    @Published private(set) var status: NEVPNStatus = .invalid

    private var manager: NETunnelProviderManager?
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)
            .compactMap { ($0.object as? NEVPNConnection)?.status }
            .receive(on: DispatchQueue.main)
            .assign(to: &$status)
    }

    func refresh() async throws {
        let m = try await loadOrCreateManager()
        manager = m
        status = m.connection.status
    }

    func configure(_ cfg: TunnelConfiguration) async throws {
        let m = try await loadOrCreateManager()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = Self.extensionBundleID
        proto.serverAddress = cfg.peerEndpoint
        proto.providerConfiguration = ["configRef": "default"]

        m.protocolConfiguration = proto
        m.localizedDescription = "Lite Secure Tunnel"
        m.isEnabled = true

        do {
            try await m.saveToPreferences()
            try await m.loadFromPreferences()
        } catch {
            throw VPNError.underlying(error)
        }

        manager = m
    }

    func start() throws {
        guard let m = manager else { throw VPNError.notConfigured }
        do {
            try m.connection.startVPNTunnel()
        } catch {
            throw VPNError.underlying(error)
        }
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let all = try await NETunnelProviderManager.loadAllFromPreferences()
        return all.first ?? NETunnelProviderManager()
    }
}
