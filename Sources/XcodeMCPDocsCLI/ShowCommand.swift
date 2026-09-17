import ArgumentParser
import Foundation
import XcodeMCPDocsKit

struct ShowCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show the details of a single tool."
    )

    @OptionGroup var bridge: BridgeOptions

    @Argument(help: ArgumentHelp("The tool name. Case-insensitive.", valueName: "tool"))
    var name: String

    @Flag(name: .customLong("json"), help: "Print the raw JSON, including the schema.")
    var asJSON = false

    func run() throws {
        let catalog = try bridge.makeCatalog()
        guard let tool = catalog.tools.first(where: { $0.name.lowercased() == name.lowercased() }) else {
            throw ValidationError(notFoundMessage(in: catalog))
        }

        if asJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            print(String(decoding: try encoder.encode(tool), as: UTF8.self))
            return
        }
        print(MarkdownRenderer().render(tool))
    }

    /// Builds the not-found message, suggesting similar names when there are any.
    private func notFoundMessage(in catalog: ToolCatalog) -> String {
        let candidates = catalog.tools
            .map(\.name)
            .filter { $0.lowercased().contains(name.lowercased()) }
        guard !candidates.isEmpty else {
            return "There is no tool named \(name). Run `xcode-mcp-docs list` to see them all."
        }
        return "There is no tool named \(name). Did you mean: \(candidates.joined(separator: ", "))"
    }
}
