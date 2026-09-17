import ArgumentParser

@main
struct XcodeMCPDocs: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcode-mcp-docs",
        abstract: "Fetch and list the tools exposed by Xcode's MCP server.",
        version: "0.1.0",
        subcommands: [ListCommand.self, ShowCommand.self, GenerateCommand.self, JSONCommand.self],
        defaultSubcommand: ListCommand.self
    )
}
