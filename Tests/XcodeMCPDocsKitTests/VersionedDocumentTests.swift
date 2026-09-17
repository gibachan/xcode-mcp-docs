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

    func testParsesBetaOutOfFileName() {
        let document = VersionedDocument(fileName: "xcode-27.2-beta-mcp-tools.html")
        XCTAssertEqual(document?.version, "27.2")
        XCTAssertEqual(document?.isBeta, true)
    }

    func testNonBetaFileNameIsNotBeta() {
        let document = VersionedDocument(fileName: "xcode-27.2-mcp-tools.html")
        XCTAssertEqual(document?.isBeta, false)
    }

    /// The trailing `-beta` must not corrupt the numeric version used for sorting.
    func testSortsBetaVersionsNumerically() {
        let documents = ["xcode-27.0-mcp-tools.html", "xcode-27.2-beta-mcp-tools.html"]
            .compactMap(VersionedDocument.init(fileName:))
        let sorted = VersionedDocument.sortedByVersionDescending(documents)
        XCTAssertEqual(sorted.map(\.version), ["27.2", "27.0"])
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

    func testMarksBetaVersionInOptionLabel() {
        let documents = [VersionedDocument(fileName: "xcode-27.2-beta-mcp-tools.html")!]
        let html = IndexRenderer().render(documents)
        XCTAssertTrue(html.contains(#">Xcode 27.2 (Beta)</option>"#))
    }

    // MARK: - Language switcher

    func testOmitsLanguagePickerWhenNoTranslationExists() {
        let documents = [VersionedDocument(fileName: "xcode-27.0-mcp-tools.html")!]
        let html = IndexRenderer().render(documents)
        XCTAssertFalse(html.contains(#"id="lang""#))
    }

    func testShowsLanguagePickerAndFlagsTranslatedVersions() {
        let documents = [
            VersionedDocument(fileName: "xcode-27.0-mcp-tools.html")!,
            VersionedDocument(fileName: "xcode-26.6-mcp-tools.html")!,
        ]
        let html = IndexRenderer().render(documents, availableInJapanese: ["xcode-27.0-mcp-tools.html"])

        XCTAssertTrue(html.contains(#"id="lang""#))
        XCTAssertTrue(html.contains(#"<option value="xcode-27.0-mcp-tools.html" selected data-ja="1">Xcode 27.0</option>"#))
        XCTAssertTrue(html.contains(#"<option value="xcode-26.6-mcp-tools.html">Xcode 26.6</option>"#))
    }
}
