//
//  SimulatorDetectorTests.swift
//  LiteSecureTunnel-iOSTests
//
//  Created by Leo Nguyen on 21/4/26.
//

import XCTest
@testable import LiteSecureTunnel_iOS

final class SimulatorDetectorTests: XCTestCase {

    func test_isSimulator_returnsTrue_onSimulator() {
        #if targetEnvironment(simulator)
        XCTAssertTrue(SimulatorDetector.isSimulator)
        #else
        XCTAssertFalse(SimulatorDetector.isSimulator)
        #endif
    }
}
