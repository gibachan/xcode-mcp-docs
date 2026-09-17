import Foundation
import XCTest
@testable import XcodeMCPDocsKit

final class VersionedDocumentTests: XCTestCase {
    func testParsesVersionOutOfFileName() {
        let document = VersionedDocument(fileName: "xcode-26.6-mcp-tools.html")
        XCTAssertEqual(document?.version, "26.6")
    }

    func testRejectsUnrelatedFileNames() {
        XCTAssertNil(VersionedDocument(fileName: "index.html"))
        XCTAssertNil(VersionedDocument(fileName: "xcode-mcp-tools.html"))
        XCTAssertNil(VersionedDocument(fileName: "xcode-26.6-mcp-tools.md"))
    }

    func testSortsNewestVersionFirstNumerically() {
        let documents = ["xcode-9.0-mcp-tools.html", "xcode-26.6-mcp-tools.html", "xcode-27.2-mcp-tools.html"]
            .compactMap(VersionedDocument.init(fileName:))
        let sorted = VersionedDocument.sortedByVersionDescending(documents)
        // A plain string sort would put "9.0" ahead of "26.6" and "27.2"; this must not.
        XCTAssertEqual(sorted.map(\.version), ["27.2", "26.6", "9.0"])
    }
}

final class IndexRendererTests: XCTestCase {
    func testRendersAnOptionAndIframePerDocument() {
        let documents = [
            VersionedDocument(fileName: "xcode-27.0-mcp-tools.html")!,
            VersionedDocument(fileName: "xcode-26.6-mcp-tools.html")!,
        ]
        let html = IndexRenderer().render(documents)

        XCTAssertTrue(html.contains(#"<option value="xcode-27.0-mcp-tools.html" selected>Xcode 27.0</option>"#))
        XCTAssertTrue(html.contains(#"<option value="xcode-26.6-mcp-tools.html">Xcode 26.6</option>"#))
        XCTAssertTrue(html.contains(#"src="xcode-27.0-mcp-tools.html""#), "the iframe should default to the first (newest) document")
    }

    func testExplainsThatNothingHasBeenGeneratedYetWhenEmpty() {
        let html = IndexRenderer().render([])
        XCTAssertTrue(html.contains("No documentation has been generated yet"))
    }
}
