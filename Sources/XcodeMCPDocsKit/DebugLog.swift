import Foundation

/// Writes progress to standard error only when `XCODE_MCP_DOCS_DEBUG` is set.
enum DebugLog {
    static let isEnabled = ProcessInfo.processInfo.environment["XCODE_MCP_DOCS_DEBUG"] != nil

    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        FileHandle.standardError.write(Data("[xcode-mcp-docs] \(message())\n".utf8))
    }
}
