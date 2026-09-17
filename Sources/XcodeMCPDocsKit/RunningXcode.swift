import Foundation

/// A running Xcode (the GUI app itself).
public struct RunningXcode: Equatable {
    public let pid: Int32
    /// Path of the bundle, such as `/Applications/Xcode-27.app`.
    public let bundleURL: URL
}

public extension XcodeLocator {
    /// Lists the running Xcodes.
    ///
    /// The mcpbridge that ships with Xcode 26 can only connect to an already running Xcode,
    /// so we choose the target ourselves and pass it through `MCP_XCODE_PID`.
    static func runningXcodes() -> [RunningXcode] {
        guard let output = try? processOutput("/bin/ps", ["-Ao", "pid=,comm="]) else { return [] }
        return output
            .split(separator: "\n")
            .compactMap(parseProcessLine)
    }

    /// The running process that corresponds to the given Xcode bundle.
    static func runningXcode(matching bundleURL: URL) -> RunningXcode? {
        let target = bundleURL.standardizedFileURL.path
        return runningXcodes().first { $0.bundleURL.path == target }
    }

    /// Works back from an mcpbridge path to the Xcode bundle that contains it.
    static func bundle(forBridge bridgeURL: URL) -> URL? {
        var url = bridgeURL.standardizedFileURL
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            if url.pathExtension == "app" { return url }
        }
        return nil
    }

    private static func parseProcessLine(_ line: Substring) -> RunningXcode? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let separator = trimmed.firstIndex(of: " ") else { return nil }
        guard let pid = Int32(trimmed[trimmed.startIndex..<separator]) else { return nil }

        let command = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        // Pick up Xcode itself only, not Xcode Service or DeviceHub.
        guard command.hasSuffix(".app/Contents/MacOS/Xcode") else { return nil }

        let binaryURL = URL(fileURLWithPath: command)
        guard let bundleURL = bundle(forBridge: binaryURL) else { return nil }
        return RunningXcode(pid: pid, bundleURL: bundleURL)
    }

    private static func processOutput(_ launchPath: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
