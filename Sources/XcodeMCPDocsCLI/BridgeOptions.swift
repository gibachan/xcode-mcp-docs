import ArgumentParser
import Foundation
import XcodeMCPDocsKit

/// Shared options that decide which Xcode's MCP server to query.
struct BridgeOptions: ParsableArguments {
    @Option(
        name: .customLong("xcode"),
        help: ArgumentHelp(
            "The target Xcode: a path to Xcode.app, a Developer directory, or the mcpbridge binary.",
            discussion: "Defaults to whichever Xcode xcode-select has selected.",
            valueName: "path"
        )
    )
    var xcode: String?

    @Option(
        name: .customLong("pid"),
        help: ArgumentHelp(
            "Process ID of the Xcode to connect to (passed as MCP_XCODE_PID).",
            discussion: """
                When omitted, mcpbridge chooses the target itself. On Xcode 27 and later the \
                headless Xcode Service answers, so leaving this unset is the safer bet. Naming a \
                running GUI Xcode can go unanswered if the agent is unapproved there.
                """,
            valueName: "pid"
        )
    )
    var pid: Int32?

    @Option(
        name: .customLong("timeout"),
        help: ArgumentHelp("Seconds to wait for each response.", valueName: "seconds")
    )
    var timeout: Double = 30

    func makeCatalog() throws -> ToolCatalog {
        let bridgeURL = try XcodeLocator.resolveBridge(xcode: xcode)
        let client = MCPBridgeClient(bridgeURL: bridgeURL, xcodePID: pid, timeout: timeout)
        do {
            return try client.fetchCatalog()
        } catch let error as XcodeMCPDocsError {
            throw refine(error, bridgeURL: bridgeURL)
        }
    }

    /// Adds whatever cause can be inferred from the surrounding situation to the error.
    private func refine(_ error: XcodeMCPDocsError, bridgeURL: URL) -> XcodeMCPDocsError {
        let running = XcodeLocator.runningXcodes().map { "\($0.bundleURL.lastPathComponent) (pid \($0.pid))" }

        switch error {
        case .bridgeExited(_, let stderr) where stderr.contains("no running Xcode processes found"):
            return .xcodeNotRunning(
                bundlePath: XcodeLocator.bundle(forBridge: bridgeURL)?.path ?? bridgeURL.path,
                running: running
            )
        case .timeout(let stage, let seconds, _) where pid != nil:
            return .unapprovedAgent(stage: stage, seconds: seconds, pid: pid)
        default:
            return error
        }
    }
}
