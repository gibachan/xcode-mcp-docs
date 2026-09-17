import Foundation
import XCTest
@testable import XcodeMCPDocsKit

final class ToolDecodingTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "tools-list", withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    private func decodeTools() throws -> [Tool] {
        struct Response: Decodable {
            let result: ToolListResult
        }
        return try JSONDecoder().decode(Response.self, from: fixtureData()).result.tools
    }

    func testDecodesAllTools() throws {
        let tools = try decodeTools()
        XCTAssertEqual(tools.map(\.name).sorted(), ["AddEntitlement", "RunSomeTests", "XcodeRead"])
    }

    func testSummaryUsesFirstLineOfDescription() throws {
        let tool = try XCTUnwrap(decodeTools().first { $0.name == "AddEntitlement" })
        XCTAssertEqual(tool.summary, "Add a new entitlement to the project's entitlements file.")
    }

    func testReadsRequiredParameters() throws {
        let tool = try XCTUnwrap(decodeTools().first { $0.name == "RunSomeTests" })
        XCTAssertEqual(tool.requiredParameters, ["tests"])
        XCTAssertEqual(tool.parameterNames, ["tests", "workspaceIdentifier"])
    }

    func testKeepsNestedSchemaStructure() throws {
        let tool = try XCTUnwrap(decodeTools().first { $0.name == "RunSomeTests" })
        let itemType = tool.inputSchema?["properties"]?["tests"]?["items"]?["type"]?.stringValue
        XCTAssertEqual(itemType, "object")
    }

    func testDecodesOutputSchema() throws {
        let tool = try XCTUnwrap(decodeTools().first { $0.name == "RunSomeTests" })
        XCTAssertNotNil(tool.outputSchema?["properties"])
    }
}
