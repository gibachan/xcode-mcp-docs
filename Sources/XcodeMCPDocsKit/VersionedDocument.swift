import Foundation

/// A generated per-Xcode-version HTML document, as found on disk in the output directory.
///
/// Matches file names produced by `generate`'s default naming, e.g. `xcode-26.6-mcp-tools.html`.
/// Anything else (including `index.html` itself, or Markdown output) does not match.
public struct VersionedDocument: Equatable {
    public let version: String
    public let fileName: String

    private static let pattern = try! NSRegularExpression(pattern: "^xcode-(.+)-mcp-tools\\.html$")

    public init?(fileName: String) {
        let range = NSRange(fileName.startIndex..., in: fileName)
        guard let match = Self.pattern.firstMatch(in: fileName, range: range),
              let versionRange = Range(match.range(at: 1), in: fileName)
        else { return nil }
        self.version = String(fileName[versionRange])
        self.fileName = fileName
    }

    public init?(fileURL: URL) {
        self.init(fileName: fileURL.lastPathComponent)
    }

    /// Newest version first, comparing dotted components numerically (`27.2` before `26.6`).
    public static func sortedByVersionDescending(_ documents: [VersionedDocument]) -> [VersionedDocument] {
        documents.sorted { isNewer($0.version, than: $1.version) }
    }

    private static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let left = components(lhs)
        let right = components(rhs)
        for (l, r) in zip(left, right) where l != r { return l > r }
        return left.count > right.count
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
