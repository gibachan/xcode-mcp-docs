import Foundation

/// Resolves the mcpbridge binary from the specified Xcode.
public enum XcodeLocator {
    static let bridgeRelativePath = "Contents/Developer/usr/bin/mcpbridge"

    /// Resolves the `--xcode` value to a path to mcpbridge.
    ///
    /// Accepted forms:
    /// - `/Applications/Xcode-27.app`
    /// - `/Applications/Xcode-27.app/Contents/Developer`
    /// - an absolute path to mcpbridge itself
    /// - `nil` (use whichever Xcode `xcode-select` has selected)
    public static func resolveBridge(xcode: String?) throws -> URL {
        guard let xcode else { return try selectedBridge() }

        let path = (xcode as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let candidates: [URL]

        if url.lastPathComponent == "mcpbridge" {
            candidates = [url]
        } else if url.pathExtension == "app" {
            candidates = [url.appendingPathComponent(bridgeRelativePath)]
        } else if url.lastPathComponent == "Developer" {
            candidates = [url.appendingPathComponent("usr/bin/mcpbridge")]
        } else {
            candidates = [
                url.appendingPathComponent(bridgeRelativePath),
                url.appendingPathComponent("usr/bin/mcpbridge"),
            ]
        }

        guard let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw XcodeMCPDocsError.bridgeNotFound(path: candidates[0].path)
        }
        return found
    }

    /// The mcpbridge of the Xcode currently selected by `xcode-select`.
    static func selectedBridge() throws -> URL {
        if let path = try? runCapturing("/usr/bin/xcrun", ["-f", "mcpbridge"]),
           FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        if let developer = try? runCapturing("/usr/bin/xcode-select", ["-p"]) {
            let url = URL(fileURLWithPath: developer).appendingPathComponent("usr/bin/mcpbridge")
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        throw XcodeMCPDocsError.bridgeNotFound(path: "xcrun -f mcpbridge")
    }

    /// The `CFBundleShortVersionString` of an `Xcode.app` bundle, e.g. `"26.6"`.
    public static func xcodeVersion(forBundle bundleURL: URL) -> String? {
        infoPlist(forBundle: bundleURL)?["CFBundleShortVersionString"] as? String
    }

    /// The Xcode version of the bundle that contains the given `mcpbridge`, if it can be resolved.
    public static func xcodeVersion(forBridge bridgeURL: URL) -> String? {
        guard let bundleURL = bundle(forBridge: bridgeURL) else { return nil }
        return xcodeVersion(forBundle: bundleURL)
    }

    /// The `DTXcodeBuild` of an `Xcode.app` bundle, e.g. `"27A266"` — the build identifier shown
    /// in parentheses in Xcode's "About Xcode" window.
    public static func xcodeBuild(forBundle bundleURL: URL) -> String? {
        infoPlist(forBundle: bundleURL)?["DTXcodeBuild"] as? String
    }

    /// The Xcode build of the bundle that contains the given `mcpbridge`, if it can be resolved.
    public static func xcodeBuild(forBridge bridgeURL: URL) -> String? {
        guard let bundleURL = bundle(forBridge: bridgeURL) else { return nil }
        return xcodeBuild(forBundle: bundleURL)
    }

    /// Whether an `Xcode.app` bundle is a beta build. Beta Xcodes use a distinct icon named
    /// e.g. `XcodeBeta`, so `CFBundleIconName`/`CFBundleIconFile` containing "Beta" is Apple's own
    /// signal — there is no dedicated "is beta" key in Info.plist.
    public static func isBeta(forBundle bundleURL: URL) -> Bool {
        guard let plist = infoPlist(forBundle: bundleURL) else { return false }
        let iconName = (plist["CFBundleIconName"] as? String) ?? (plist["CFBundleIconFile"] as? String) ?? ""
        return iconName.localizedCaseInsensitiveContains("beta")
    }

    /// Whether the bundle that contains the given `mcpbridge` is a beta build.
    public static func isBeta(forBridge bridgeURL: URL) -> Bool {
        guard let bundleURL = bundle(forBridge: bridgeURL) else { return false }
        return isBeta(forBundle: bundleURL)
    }

    private static func infoPlist(forBundle bundleURL: URL) -> [String: Any]? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// Xcodes installed under `/Applications`, used to guide the user in error messages.
    public static func installedXcodes() -> [URL] {
        let applications = URL(fileURLWithPath: "/Applications")
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: applications,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents
            .filter { $0.pathExtension == "app" && $0.lastPathComponent.hasPrefix("Xcode") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func runCapturing(_ launchPath: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw XcodeMCPDocsError.bridgeNotFound(path: launchPath)
        }
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
