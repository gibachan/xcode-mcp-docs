import ArgumentParser
import Foundation

struct ReindexCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reindex",
        abstract: "Rebuilds index.html from the HTML docs already on disk, without querying Xcode.",
        discussion: """
            Picks up every xcode-<version>-mcp-tools.html in the directory (English) plus any \
            translations at ja/<same-filename>, and rewrites index.html's version/language \
            switcher accordingly. Useful after adding a translation without regenerating the \
            English doc it was translated from.
            """
    )

    @Option(
        name: .customLong("directory"),
        help: ArgumentHelp("Directory containing the versioned HTML docs.", valueName: "path")
    )
    var directory: String = "Documentations"

    func run() throws {
        let directoryURL = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath)
        try IndexBuilder.rebuildIndex(in: directoryURL)
        FileHandle.standardError.write(
            Data("Rebuilt \(directoryURL.appendingPathComponent("index.html").path)\n".utf8)
        )
    }
}
