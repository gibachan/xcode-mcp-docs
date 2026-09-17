import Foundation

public enum XcodeMCPDocsError: LocalizedError {
    case bridgeNotFound(path: String)
    case launchFailed(path: String, underlying: String)
    case timeout(stage: String, seconds: TimeInterval, bridgePath: String)
    case bridgeExited(status: Int32, stderr: String)
    case rpcError(code: Int, message: String)
    case malformedResponse(stage: String, detail: String)
    case xcodeNotRunning(bundlePath: String, running: [String])
    case unapprovedAgent(stage: String, seconds: TimeInterval, pid: Int32?)

    public var errorDescription: String? {
        switch self {
        case .bridgeNotFound(let path):
            return """
            mcpbridge not found: \(path)
            Xcode 26 or later is required. Pass the path to an Xcode.app with --xcode.
            """
        case .launchFailed(let path, let underlying):
            return "Failed to launch mcpbridge (\(path)): \(underlying)"
        case .timeout(let stage, let seconds, let bridgePath):
            return """
            No response to \(stage) within \(Int(seconds)) seconds (\(bridgePath))
            Extend the wait with --timeout, or launch the target Xcode once and try again.
            """
        case .unapprovedAgent(let stage, let seconds, let pid):
            let target = pid.map { "pid \($0)" } ?? "the specified Xcode"
            return """
            No response to \(stage) within \(Int(seconds)) seconds (target: \(target)).
            When a GUI Xcode is named explicitly, it never answers if this agent is unapproved there.
            Drop --pid and let mcpbridge choose the target, or approve the agent in Xcode and retry.
            """
        case .bridgeExited(let status, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = trimmed.isEmpty ? "" : "\n\(trimmed)"
            return "mcpbridge exited with status \(status)\(suffix)"
        case .rpcError(let code, let message):
            return "The MCP server returned an error (code: \(code)): \(message)"
        case .malformedResponse(let stage, let detail):
            return "Could not interpret the response to \(stage): \(detail)"
        case .xcodeNotRunning(let bundlePath, let running):
            let runningList = running.isEmpty
                ? "No Xcode is running."
                : "Running Xcodes: \(running.joined(separator: ", "))"
            return """
            Could not connect to the MCP server of \(bundlePath).
            The mcpbridge of Xcode 26.x only connects to a running Xcode (headless needs Xcode 27+).
            Launch the target Xcode and try again, or pass a process ID with --pid.
            \(runningList)
            """
        }
    }
}

extension XcodeMCPDocsError: CustomStringConvertible {
    public var description: String { errorDescription ?? "Unknown error" }
}
