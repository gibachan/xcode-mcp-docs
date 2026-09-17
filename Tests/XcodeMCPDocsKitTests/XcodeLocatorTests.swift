import Foundation
import XCTest
@testable import XcodeMCPDocsKit

final class XcodeLocatorTests: XCTestCase {
    func testDerivesBundleFromBridgePath() {
        let bridge = URL(fileURLWithPath: "/Applications/Xcode-27.app/Contents/Developer/usr/bin/mcpbridge")
        XCTAssertEqual(
            XcodeLocator.bundle(forBridge: bridge)?.path,
            "/Applications/Xcode-27.app"
        )
    }

    func testReturnsNilWhenPathIsNotInsideABundle() {
        let bridge = URL(fileURLWithPath: "/usr/local/bin/mcpbridge")
        XCTAssertNil(XcodeLocator.bundle(forBridge: bridge))
    }

    func testRejectsXcodeWithoutBridge() {
        XCTAssertThrowsError(try XcodeLocator.resolveBridge(xcode: "/Applications/DoesNotExist.app")) { error in
            guard case XcodeMCPDocsError.bridgeNotFound = error else {
                return XCTFail("expected bridgeNotFound but got \(error)")
            }
        }
    }
}
