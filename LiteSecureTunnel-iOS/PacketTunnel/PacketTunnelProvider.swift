//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by Leo Nguyen on 20/4/26.
//

import NetworkExtension
import os.log

#if canImport(WireGuardKit) && !targetEnvironment(simulator)
import WireGuardKit
#endif

enum TunnelError: LocalizedError {
    case missingPrivateKey
    case missingConfig
    case invalidPrivateKey
    case invalidPeerKey
    case invalidEndpoint
    case adapterStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPrivateKey: return "Private key missing in Keychain"
        case .missingConfig: return "Tunnel configuration missing in App Group"
        case .invalidPrivateKey: return "Private key could not be decoded"
        case .invalidPeerKey: return "Peer public key could not be decoded"
        case .invalidEndpoint: return "Peer endpoint could not be parsed"
        case .adapterStartFailed(let msg): return "WireGuard adapter failed: \(msg)"
        }
    }
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    #if canImport(WireGuardKit) && !targetEnvironment(simulator)
    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { logLevel, message in
            os_log("%{public}@ %{public}@",
                   log: TunnelLog.network,
                   type: logLevel == .error ? .error : .default,
                   "\(logLevel)", message)
        }
    }()
    #endif

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("startTunnel called", log: TunnelLog.lifecycle, type: .info)

        #if canImport(WireGuardKit) && !targetEnvironment(simulator)
        do {
            let tunnelConfiguration = try buildTunnelConfiguration()

            adapter.start(tunnelConfiguration: tunnelConfiguration) { adapterError in
                if let adapterError {
                    os_log("adapter.start failed: %{public}@",
                           log: TunnelLog.lifecycle, type: .error,
                           String(describing: adapterError))
                    completionHandler(TunnelError.adapterStartFailed(String(describing: adapterError)))
                } else {
                    os_log("tunnel started", log: TunnelLog.lifecycle, type: .info)
                    completionHandler(nil)
                }
            }
        } catch {
            os_log("startTunnel error: %{public}@",
                   log: TunnelLog.lifecycle, type: .error,
                   String(describing: error))
            completionHandler(error)
        }
        #else
        // WireGuardKit not linked — integration pending paid Apple Developer account.
        // See README "Why WireGuardKit is deferred".
        completionHandler(NSError(domain: "PacketTunnel", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Tunnel not implemented yet (WireGuardKit not linked)"
        ]))
        #endif
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("stopTunnel called, reason=%d", log: TunnelLog.lifecycle, type: .info, reason.rawValue)

        #if canImport(WireGuardKit) && !targetEnvironment(simulator)
        adapter.stop { error in
            if let error {
                os_log("adapter.stop error: %{public}@",
                       log: TunnelLog.lifecycle, type: .error,
                       String(describing: error))
            }
            completionHandler()
        }
        #else
        completionHandler()
        #endif
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // No IPC protocol defined between app and extension for this project.
        completionHandler?(nil)
    }

    // MARK: - Config

    #if canImport(WireGuardKit) && !targetEnvironment(simulator)
    /// Assemble a WireGuardKit `TunnelConfiguration` from:
    /// - Private key in shared Keychain (access group) — never in `providerConfiguration`
    /// - Routing data from App Group UserDefaults — non-secret, safe to share
    private func buildTunnelConfiguration() throws -> WireGuardKit.TunnelConfiguration {
        guard let privateKeyData = try KeychainStore.load() else {
            throw TunnelError.missingPrivateKey
        }
        guard let privateKey = PrivateKey(rawValue: privateKeyData) else {
            throw TunnelError.invalidPrivateKey
        }
        guard let config = AppGroupConfigStore.load() else {
            throw TunnelError.missingConfig
        }
        guard let peerPublicKey = PublicKey(base64Key: config.peerPublicKey) else {
            throw TunnelError.invalidPeerKey
        }
        guard let endpoint = Endpoint(from: config.peerEndpoint) else {
            throw TunnelError.invalidEndpoint
        }

        var interface = InterfaceConfiguration(privateKey: privateKey)
        interface.addresses = config.interfaceAddress
            .split(separator: ",")
            .compactMap { IPAddressRange(from: $0.trimmingCharacters(in: .whitespaces)) }
        interface.dns = config.dnsServers.compactMap { DNSServer(from: $0) }

        var peer = PeerConfiguration(publicKey: peerPublicKey)
        peer.endpoint = endpoint
        peer.allowedIPs = config.allowedIPs
            .compactMap { IPAddressRange(from: $0) }
        if let pskString = config.presharedKey,
           let psk = PreSharedKey(base64Key: pskString) {
            peer.preSharedKey = psk
        }

        return WireGuardKit.TunnelConfiguration(name: "ios-test", interface: interface, peers: [peer])
    }
    #endif
}
