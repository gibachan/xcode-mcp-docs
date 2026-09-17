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

    // MARK: - xcodeVersion

    func testReadsVersionFromBundleInfoPlist() throws {
        let bundleURL = try makeFakeBundle(named: "Xcode-26.6.app", shortVersion: "26.6")
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        XCTAssertEqual(XcodeLocator.xcodeVersion(forBundle: bundleURL), "26.6")
    }

    func testReadsVersionFromBridgePathByWalkingUpToTheBundle() throws {
        let bundleURL = try makeFakeBundle(named: "Xcode-27.app", shortVersion: "27.0")
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        let bridgeURL = bundleURL.appendingPathComponent(XcodeLocator.bridgeRelativePath)
        XCTAssertEqual(XcodeLocator.xcodeVersion(forBridge: bridgeURL), "27.0")
    }

    func testVersionIsNilWhenInfoPlistIsMissing() {
        let bundleURL = URL(fileURLWithPath: "/Applications/DoesNotExist.app")
        XCTAssertNil(XcodeLocator.xcodeVersion(forBundle: bundleURL))
    }

    // MARK: - isBeta

    /// Beta Xcodes use a distinct app icon (e.g. `XcodeBeta`); that's the only signal Info.plist
    /// gives for beta-ness, so this is what `isBeta` keys off of.
    func testDetectsBetaFromIconName() throws {
        let bundleURL = try makeFakeBundle(named: "Xcode-27.2-beta.app", shortVersion: "27.2", iconName: "XcodeBeta")
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        XCTAssertTrue(XcodeLocator.isBeta(forBundle: bundleURL))
    }

    func testIsNotBetaForARegularIconName() throws {
        let bundleURL = try makeFakeBundle(named: "Xcode-27.app", shortVersion: "27.0", iconName: "Xcode")
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        XCTAssertFalse(XcodeLocator.isBeta(forBundle: bundleURL))
    }

    func testIsNotBetaWhenInfoPlistIsMissing() {
        let bundleURL = URL(fileURLWithPath: "/Applications/DoesNotExist.app")
        XCTAssertFalse(XcodeLocator.isBeta(forBundle: bundleURL))
    }

    /// Builds a throwaway `Foo.app/Contents/Info.plist` under a temp directory so version
    /// lookup can be tested without touching a real Xcode installation.
    private func makeFakeBundle(named name: String, shortVersion: String, iconName: String? = nil) throws -> URL {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name)
        let contentsURL = bundleURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        var plist: [String: Any] = ["CFBundleShortVersionString": shortVersion]
        if let iconName { plist["CFBundleIconName"] = iconName }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        return bundleURL
    }
}
