//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by Leo Nguyen on 20/4/26.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Phase 04 will implement WireGuardAdapter integration
        let error = NSError(domain: "PacketTunnel", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Tunnel not implemented yet"
        ])
        completionHandler(error)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Phase 04 will implement shutdown
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Optional IPC from app — not used in this project
        completionHandler?(nil)
    }
}
