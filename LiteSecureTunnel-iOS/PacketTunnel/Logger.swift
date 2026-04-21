//
//  Logger.swift
//  PacketTunnel
//
//  Created by Leo Nguyen on 21/4/26.
//

import Foundation
import os.log

enum TunnelLog {
    static let subsystem = "com.leonguyen.LiteSecureTunnel-iOS.PacketTunnel"

    static let lifecycle = OSLog(subsystem: subsystem, category: "lifecycle")
    static let config = OSLog(subsystem: subsystem, category: "config")
    static let network = OSLog(subsystem: subsystem, category: "network")
}
