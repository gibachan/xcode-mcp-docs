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
        help: ArgumentHelp(
            "Where to write. `-` for standard output. Defaults to Documentations/xcode-<version>-mcp-tools.<extension>",
            valueName: "path"
        )
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

        // Falling back to the versioned default (rather than an explicit -o) is also what
        // decides whether Documentations/index.html gets rebuilt below.
        let usesDefaultLocation = output == nil
        let path = output ?? Self.defaultOutputPath(for: catalog, format: format)
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(document.utf8).write(to: url)
        FileHandle.standardError.write(
            Data("Wrote \(catalog.tools.count) tools to \(url.path)\n".utf8)
        )

        if usesDefaultLocation, format == .html {
            try IndexBuilder.rebuildIndex(in: directory)
        }

        if openAfterWrite {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [url.path]
            try process.run()
            process.waitUntilExit()
        }
    }

    /// `Documentations/xcode-<version>[-beta]-mcp-tools.<ext>`. Falls back to a version-less name
    /// when the Xcode version can't be determined, e.g. `--xcode` pointed straight at `mcpbridge`.
    private static func defaultOutputPath(for catalog: ToolCatalog, format: Format) -> String {
        let versionSegment = catalog.xcodeVersion.map { catalog.xcodeIsBeta ? "\($0)-beta" : $0 }
        let base = versionSegment.map { "xcode-\($0)-mcp-tools" } ?? "xcode-mcp-tools"
        return "Documentations/\(base).\(format.fileExtension)"
    }
}
