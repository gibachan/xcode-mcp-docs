import Foundation
import XCTest
@testable import XcodeMCPDocsKit

final class RenderingTests: XCTestCase {
    private func fixtureTools() throws -> [Tool] {
        struct Response: Decodable {
            let result: ToolListResult
        }
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "tools-list", withExtension: "json", subdirectory: "Fixtures")
        )
        return try JSONDecoder().decode(Response.self, from: Data(contentsOf: url)).result.tools
    }

    private func makeCatalog(
        _ tools: [Tool],
        xcodeVersion: String? = nil,
        xcodeBuild: String? = nil
    ) -> ToolCatalog {
        ToolCatalog(
            bridgePath: "/Applications/Xcode-27.app/Contents/Developer/usr/bin/mcpbridge",
            protocolVersion: "2024-11-05",
            serverInfo: ServerInfo(name: "xcode-tools", version: "25317"),
            tools: tools,
            fetchedAt: Date(timeIntervalSince1970: 0),
            xcodeVersion: xcodeVersion,
            xcodeBuild: xcodeBuild
        )
    }

    // MARK: - SchemaNode

    func testFlattensNestedArraySchema() throws {
        let tool = try XCTUnwrap(fixtureTools().first { $0.name == "RunSomeTests" })
        let root = try XCTUnwrap(tool.inputSchemaTree)

        let tests = try XCTUnwrap(root.children.first { $0.name == "tests" })
        XCTAssertEqual(tests.type, "array<object>")
        XCTAssertTrue(tests.isRequired)
        XCTAssertEqual(tests.children.map(\.name), ["targetName", "testIdentifier"])
    }

    func testRequiredParametersComeFirst() throws {
        let tool = try XCTUnwrap(fixtureTools().first { $0.name == "RunSomeTests" })
        let root = try XCTUnwrap(tool.inputSchemaTree)
        XCTAssertEqual(root.children.map(\.name), ["tests", "workspaceIdentifier"])
    }

    // MARK: - ToolCategory

    func testAssignsCategoriesByName() {
        XCTAssertEqual(ToolCategory.category(for: "XcodeRead").name, "File operations")
        XCTAssertEqual(ToolCategory.category(for: "DeviceInteractionSynthesize").name, "Device interaction")
        XCTAssertEqual(ToolCategory.category(for: "GetTopCrashIssues").name, "Crashes / Performance")
    }

    /// New, unknown tools fall into the catch-all category instead of being misclassified.
    func testUnknownToolFallsBackToOther() {
        XCTAssertEqual(ToolCategory.category(for: "BrandNewTool").name, "Other")
    }

    // MARK: - HTML

    func testHTMLContainsEveryToolWithAnchor() throws {
        let tools = try fixtureTools()
        let html = HTMLRenderer().render(makeCatalog(tools))
        for tool in tools {
            XCTAssertTrue(html.contains("id=\"tool-\(tool.name)\""), "\(tool.name) is missing from the output")
        }
    }

    func testHTMLEscapesMarkup() {
        let tool = Tool(
            name: "Dangerous",
            description: "<script>alert(\"x\")</script> & more",
            inputSchema: nil,
            outputSchema: nil
        )
        let html = HTMLRenderer().render(makeCatalog([tool]))
        XCTAssertFalse(html.contains("<script>alert"))
        XCTAssertTrue(html.contains("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; more"))
    }

    /// The document must reference no external resources, so that it opens offline.
    func testHTMLHasNoExternalResources() throws {
        let html = HTMLRenderer().render(makeCatalog(try fixtureTools()))
        XCTAssertFalse(html.contains("http://"))
        XCTAssertFalse(html.contains("https://"))
    }

    /// Tools are never collapsed; expanding and collapsing happens per category.
    func testToolsAreExpandedAndCategoriesCollapsible() throws {
        let html = HTMLRenderer().render(makeCatalog(try fixtureTools()))
        XCTAssertFalse(html.contains("<details class=\"tool\""), "a tool is collapsed")
        XCTAssertTrue(html.contains("<article class=\"tool\""))
        XCTAssertTrue(html.contains("<details class=\"category\""))
        // Every category is open by default.
        let categoryCount = html.components(separatedBy: "<details class=\"category\"").count - 1
        let openCount = html.components(separatedBy: "<details class=\"category\" data-category=").count - 1
        XCTAssertEqual(categoryCount, openCount)
        XCTAssertTrue(html.contains("open>"))
    }

    func testHTMLReportsToolCount() throws {
        let html = HTMLRenderer().render(makeCatalog(try fixtureTools()))
        XCTAssertTrue(html.contains("<span id=\"count\">3</span> / 3"))
    }

    func testHTMLShowsXcodeVersionAndBuildWhenKnown() throws {
        let html = HTMLRenderer().render(
            makeCatalog(try fixtureTools(), xcodeVersion: "27.0", xcodeBuild: "27A266")
        )
        XCTAssertTrue(html.contains("<dt>Xcode version</dt><dd>27.0</dd>"))
        XCTAssertTrue(html.contains("<dt>Build</dt><dd>27A266</dd>"))
    }

    func testHTMLOmitsXcodeMetaWhenUnknown() throws {
        let html = HTMLRenderer().render(makeCatalog(try fixtureTools()))
        XCTAssertFalse(html.contains("<dt>Xcode version</dt>"))
        XCTAssertFalse(html.contains("<dt>Build</dt>"))
    }

    // MARK: - Markdown

    func testMarkdownRendersNestedRowsWithIndent() throws {
        let tool = try XCTUnwrap(fixtureTools().first { $0.name == "RunSomeTests" })
        let markdown = MarkdownRenderer().render(tool)
        XCTAssertTrue(markdown.contains("| `tests` | `array<object>` | ✓ "))
        XCTAssertTrue(markdown.contains("| &nbsp;&nbsp;`targetName` | `string` | ✓ "))
    }

    func testMarkdownEscapesPipesInDescriptions() {
        let tool = Tool(
            name: "Piped",
            description: "a | b",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object(["x": .object(["type": .string("string"), "description": .string("a | b")])]),
            ]),
            outputSchema: nil
        )
        let markdown = MarkdownRenderer().render(tool)
        XCTAssertTrue(markdown.contains("a \\| b |"))
    }

    func testMarkdownStatesWhenThereAreNoParameters() {
        let tool = Tool(name: "Bare", description: nil, inputSchema: nil, outputSchema: nil)
        let markdown = MarkdownRenderer().render(tool)
        XCTAssertTrue(markdown.contains("**Input**: No parameters"))
    }
}
