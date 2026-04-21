//
//  TunnelViewModel.swift
//  LiteSecureTunnel-iOS
//
//  Created by Leo Nguyen on 20/4/26.
//

import Foundation
import NetworkExtension
import Combine

@MainActor
final class TunnelViewModel: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var statusText: String = "Disconnected"
    @Published var showSimulatorAlert: Bool = false
    @Published var errorMessage: String?

    let isSimulator = SimulatorDetector.isSimulator

    private let vpnManager = VPNManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        vpnManager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.apply(status: status)
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        if isSimulator {
            showSimulatorAlert = true
            return
        }
        #if DEBUG
        seedDevPrivateKey()
        #endif
        Task { try? await vpnManager.refresh() }
    }

    #if DEBUG
    private func seedDevPrivateKey() {
        guard (try? KeychainStore.load()) == nil,
              let data = Data(base64Encoded: Self.devPrivateKey) else { return }
        try? KeychainStore.save(data)
    }
    #endif

    func toggle() {
        guard !isSimulator else { return }

        if isConnected {
            vpnManager.stop()
        } else {
            Task { await connect() }
        }
    }

    private func connect() async {
        do {
            let config = Self.devSampleConfig()
            try await vpnManager.configure(config)
            try vpnManager.start()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func apply(status: NEVPNStatus) {
        switch status {
        case .connected:
            isConnected = true
            statusText = "Connected"
        case .connecting:
            statusText = "Connecting…"
        case .disconnecting:
            statusText = "Disconnecting…"
        case .reasserting:
            statusText = "Reasserting…"
        case .disconnected, .invalid:
            isConnected = false
            statusText = "Disconnected"
        @unknown default:
            statusText = "Unknown"
        }
    }

    // DEBUG seeder — values from wg-easy client "ios-test" (LAN-only test server).
    // Private key loaded from Keychain separately at tunnel start.
    // For production: replace with a real config import flow (file picker / QR scan).
    private static func devSampleConfig() -> TunnelConfiguration {
        TunnelConfiguration(
            interfaceAddress: "10.8.0.2/24",
            dnsServers: ["1.1.1.1"],
            peerPublicKey: "***REMOVED***",
            peerEndpoint: "192.168.1.8:51820",
            allowedIPs: ["0.0.0.0/0", "::/0"],
            presharedKey: "***REMOVED***"
        )
    }

    #if DEBUG
    // Private key from wg-easy client "ios-test". Persists into Keychain on first app launch.
    // In production, the key would be generated on-device or imported from a secure source.
    static let devPrivateKey = "***REMOVED***"
    #endif
}
