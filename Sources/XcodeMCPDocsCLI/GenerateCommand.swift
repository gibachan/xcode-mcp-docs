import ArgumentParser
import Foundation
import XcodeMCPDocsKit

struct GenerateCommand: ParsableCommand {
    enum Format: String, ExpressibleByArgument, CaseIterable {
        case html
        case markdown

        var fileExtension: String {
            switch self {
            case .html: "html"
            case .markdown: "md"
            }
        }
    }

    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Write the tool list out as documentation."
    )

    @OptionGroup var bridge: BridgeOptions

    @Option(name: .customLong("format"), help: ArgumentHelp("Output format.", valueName: "html|markdown"))
    var format: Format = .html

    @Option(
        name: [.customShort("o"), .customLong("output")],
        help: ArgumentHelp("Where to write. `-` for standard output. Defaults to ./xcode-mcp-tools.<extension>", valueName: "path")
    )
    var output: String?

    @Flag(name: .customLong("open"), help: "Open the file after writing it.")
    var openAfterWrite = false

    func run() throws {
        let catalog = try bridge.makeCatalog()
        let document = switch format {
        case .html: HTMLRenderer().render(catalog)
        case .markdown: MarkdownRenderer().render(catalog)
        }

        if output == "-" {
            print(document)
            return
        }

        let path = output ?? "xcode-mcp-tools.\(format.fileExtension)"
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        try Data(document.utf8).write(to: url)
        FileHandle.standardError.write(
            Data("Wrote \(catalog.tools.count) tools to \(url.path)\n".utf8)
        )

        if openAfterWrite {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [url.path]
            try process.run()
            process.waitUntilExit()
        }
    }
}
