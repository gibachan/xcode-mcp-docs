import ArgumentParser
import Foundation
import XcodeMCPDocsKit

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List the tools exposed by Xcode's MCP server."
    )

    @OptionGroup var bridge: BridgeOptions

    @Flag(name: .customLong("names-only"), help: "Print only the tool names, one per line.")
    var namesOnly = false

    func run() throws {
        let catalog = try bridge.makeCatalog()

        if namesOnly {
            catalog.tools.forEach { print($0.name) }
            return
        }

        let serverInfo = catalog.serverInfo
        print("\(serverInfo.name) \(serverInfo.version)  (MCP protocol \(catalog.protocolVersion))")
        print(catalog.bridgePath)
        print("\(catalog.tools.count) tools")
        print("")

        let nameWidth = catalog.tools.map(\.name.count).max() ?? 0
        let summaryWidth = max(Terminal.width - nameWidth - 2, 40)
        for tool in catalog.tools {
            let name = tool.name.padding(toLength: max(nameWidth, tool.name.count), withPad: " ", startingAt: 0)
            print("\(name)  \(tool.summary.truncated(to: summaryWidth))")
        }
    }
}
