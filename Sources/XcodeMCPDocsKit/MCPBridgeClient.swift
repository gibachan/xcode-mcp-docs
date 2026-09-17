import Foundation

/// Launches `xcrun mcpbridge` and queries Xcode's MCP server over JSON-RPC.
///
/// `tools/list` can be fetched even when Xcode is not running and the agent is unapproved.
/// Approval is only needed to actually invoke a tool.
public struct MCPBridgeClient {
    public let bridgeURL: URL
    public let xcodePID: Int32?
    public let timeout: TimeInterval

    private static let initializeID = 1
    private static let toolListID = 2
    private static let protocolVersion = "2024-11-05"

    public init(bridgeURL: URL, xcodePID: Int32? = nil, timeout: TimeInterval = 30) {
        self.bridgeURL = bridgeURL
        self.xcodePID = xcodePID
        self.timeout = timeout
    }

    public func fetchCatalog() throws -> ToolCatalog {
        // Keep a write from killing us when mcpbridge exits first.
        signal(SIGPIPE, SIG_IGN)

        let process = Process()
        process.executableURL = bridgeURL
        if let xcodePID {
            var environment = ProcessInfo.processInfo.environment
            environment["MCP_XCODE_PID"] = String(xcodePID)
            process.environment = environment
        }

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let collector = ResponseCollector()
        let stderrBuffer = StderrBuffer()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                DebugLog.log("stdout: EOF")
            }
            collector.ingest(data)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                DebugLog.log("stderr: \(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines))")
            }
            stderrBuffer.append(data)
        }
        process.terminationHandler = { _ in
            collector.finish()
        }

        do {
            try process.run()
        } catch {
            throw XcodeMCPDocsError.launchFailed(
                path: bridgeURL.path,
                underlying: error.localizedDescription
            )
        }

        defer {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            // Closing standard input makes mcpbridge exit on its own; kill it only if it lingers.
            try? stdinPipe.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
            process.waitUntilExit()
        }

        // 1. initialize
        try send(initializeRequest(), to: stdinPipe)
        let initializeData = try waitForResponse(
            id: Self.initializeID,
            stage: "initialize",
            collector: collector,
            process: process,
            stderr: stderrBuffer
        )
        let initializeResult: InitializeResult = try decodeResult(
            from: initializeData,
            stage: "initialize"
        )

        // 2. notifications/initialized (no response)
        try send(initializedNotification(), to: stdinPipe)

        // 3. tools/list
        try send(toolListRequest(), to: stdinPipe)
        let toolListData = try waitForResponse(
            id: Self.toolListID,
            stage: "tools/list",
            collector: collector,
            process: process,
            stderr: stderrBuffer
        )
        let toolListResult: ToolListResult = try decodeResult(
            from: toolListData,
            stage: "tools/list"
        )

        return ToolCatalog(
            bridgePath: bridgeURL.path,
            protocolVersion: initializeResult.protocolVersion,
            serverInfo: initializeResult.serverInfo,
            tools: toolListResult.tools.sorted { $0.name < $1.name }
        )
    }
}

// MARK: - Building requests

private extension MCPBridgeClient {
    func initializeRequest() -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": Self.initializeID,
            "method": "initialize",
            "params": [
                "protocolVersion": Self.protocolVersion,
                "capabilities": [String: Any](),
                "clientInfo": ["name": "xcode-mcp-docs", "version": "0.1.0"],
            ],
        ]
    }

    func initializedNotification() -> [String: Any] {
        ["jsonrpc": "2.0", "method": "notifications/initialized"]
    }

    func toolListRequest() -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": Self.toolListID,
            "method": "tools/list",
            "params": [String: Any](),
        ]
    }

    func send(_ message: [String: Any], to pipe: Pipe) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        DebugLog.log("sending: \(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines))")
        do {
            try pipe.fileHandleForWriting.write(contentsOf: data)
            DebugLog.log("sent \(data.count) bytes")
        } catch {
            DebugLog.log("send failed: \(error)")
            throw error
        }
    }
}

// MARK: - Waiting for and decoding responses

private extension MCPBridgeClient {
    func waitForResponse(
        id: Int,
        stage: String,
        collector: ResponseCollector,
        process: Process,
        stderr: StderrBuffer
    ) throws -> Data {
        if let data = collector.wait(id: id, timeout: timeout) {
            return data
        }
        if !process.isRunning {
            throw XcodeMCPDocsError.bridgeExited(
                status: process.terminationStatus,
                stderr: stderr.string
            )
        }
        throw XcodeMCPDocsError.timeout(
            stage: stage,
            seconds: timeout,
            bridgePath: bridgeURL.path
        )
    }

    func decodeResult<T: Decodable>(from data: Data, stage: String) throws -> T {
        let envelope: Envelope<T>
        do {
            envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        } catch {
            throw XcodeMCPDocsError.malformedResponse(
                stage: stage,
                detail: error.localizedDescription
            )
        }

        if let rpcError = envelope.error {
            throw XcodeMCPDocsError.rpcError(code: rpcError.code, message: rpcError.message)
        }
        guard let result = envelope.result else {
            throw XcodeMCPDocsError.malformedResponse(stage: stage, detail: "result is empty")
        }
        return result
    }
}

// MARK: - JSON-RPC response envelope

private struct Envelope<Result: Decodable>: Decodable {
    struct RPCError: Decodable {
        let code: Int
        let message: String
    }

    let result: Result?
    let error: RPCError?
}

// MARK: - Accumulating standard error

private final class StderrBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
