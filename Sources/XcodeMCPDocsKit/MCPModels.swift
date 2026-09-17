import Foundation

/// How the MCP server introduces itself in the `initialize` response.
public struct ServerInfo: Codable, Equatable {
    public let name: String
    public let version: String
}

/// The result of `initialize`.
public struct InitializeResult: Codable, Equatable {
    public let protocolVersion: String
    public let serverInfo: ServerInfo
    public let capabilities: JSONValue?
}

/// A single tool as returned by `tools/list`.
public struct Tool: Codable, Equatable {
    public let name: String
    public let description: String?
    public let inputSchema: JSONValue?
    public let outputSchema: JSONValue?

    /// The first line of the description, for list output.
    public var summary: String {
        guard let description else { return "" }
        return description
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    /// Parameter names listed under `required` in the input schema.
    public var requiredParameters: [String] {
        inputSchema?["required"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    /// Parameter names found under `properties` in the input schema.
    public var parameterNames: [String] {
        (inputSchema?["properties"]?.objectValue?.keys).map { $0.sorted() } ?? []
    }
}

/// The result of `tools/list`.
public struct ToolListResult: Codable, Equatable {
    public let tools: [Tool]
}

/// Everything gathered from a single query.
public struct ToolCatalog: Codable, Equatable {
    /// Path of the mcpbridge that was actually launched.
    public let bridgePath: String
    public let protocolVersion: String
    public let serverInfo: ServerInfo
    public let tools: [Tool]
    public let fetchedAt: Date

    public init(
        bridgePath: String,
        protocolVersion: String,
        serverInfo: ServerInfo,
        tools: [Tool],
        fetchedAt: Date = Date()
    ) {
        self.bridgePath = bridgePath
        self.protocolVersion = protocolVersion
        self.serverInfo = serverInfo
        self.tools = tools
        self.fetchedAt = fetchedAt
    }
}
