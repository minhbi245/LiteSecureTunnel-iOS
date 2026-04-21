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
        // Skip if placeholder never replaced — avoids crashing dev builds of
        // forks that haven't set up a wg-easy client yet.
        guard !Self.devPrivateKey.hasPrefix("<") else { return }
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

    // DEBUG seeder — paste values from your local wg-easy client export.
    // See README "Seed a client config" for the full flow.
    //
    // Keys are deliberately NOT checked into source — treat the placeholders
    // as a setup prompt. Fill them in locally; do not commit real keys.
    //
    // For production: replace with a real config import flow (.conf file picker / QR scan).
    private static func devSampleConfig() -> TunnelConfiguration {
        TunnelConfiguration(
            interfaceAddress: "10.8.0.2/24",
            dnsServers: ["1.1.1.1"],
            peerPublicKey: "<PASTE_PEER_PUBLIC_KEY_FROM_WG_EASY>",
            peerEndpoint: "<LAN_IP>:51820",
            allowedIPs: ["0.0.0.0/0", "::/0"],
            presharedKey: nil    // Optional. Paste from wg-easy if you enabled PSK.
        )
    }

    #if DEBUG
    // Private key for the wg-easy client. Persisted into Keychain on first launch.
    // Do NOT commit a real key — replace locally before building.
    // In production the key would be generated on-device or imported securely.
    static let devPrivateKey = "<PASTE_CLIENT_PRIVATE_KEY_FROM_WG_EASY>"
    #endif
}
