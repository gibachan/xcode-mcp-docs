import ArgumentParser
import Foundation
import XcodeMCPDocsKit

struct JSONCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "json",
        abstract: "Print the fetched result as JSON, including inputSchema / outputSchema."
    )

    @OptionGroup var bridge: BridgeOptions

    @Option(
        name: [.customShort("o"), .customLong("output")],
        help: ArgumentHelp("File to write to. Defaults to standard output.", valueName: "path")
    )
    var output: String?

    @Flag(name: .customLong("compact"), help: "Print on a single line, without pretty-printing.")
    var compact = false

    func run() throws {
        let catalog = try bridge.makeCatalog()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = compact
            ? [.sortedKeys, .withoutEscapingSlashes]
            : [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(catalog)

        guard let output else {
            print(String(decoding: data, as: UTF8.self))
            return
        }
        let url = URL(fileURLWithPath: (output as NSString).expandingTildeInPath)
        try data.write(to: url)
        FileHandle.standardError.write(Data("Wrote \(catalog.tools.count) tools to \(url.path)\n".utf8))
    }
}
