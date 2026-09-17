import Foundation
import XcodeMCPDocsKit

/// Rebuilds `index.html` from whatever versioned HTML docs already sit on disk, without querying
/// Xcode. Shared by `generate` (after writing its own file) and `reindex` (standalone — e.g. after
/// a translation pass drops files into `ja/` without touching the English docs).
enum IndexBuilder {
    static func rebuildIndex(in directory: URL) throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let documents = VersionedDocument.sortedByVersionDescending(files.compactMap(VersionedDocument.init(fileURL:)))

        let japaneseDirectory = directory.appendingPathComponent("ja")
        let japaneseFiles = (try? FileManager.default.contentsOfDirectory(
            at: japaneseDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        let availableInJapanese = Set(japaneseFiles.compactMap(VersionedDocument.init(fileURL:)).map(\.fileName))

        let indexURL = directory.appendingPathComponent("index.html")
        try Data(IndexRenderer().render(documents, availableInJapanese: availableInJapanese).utf8).write(to: indexURL)
    }
}
