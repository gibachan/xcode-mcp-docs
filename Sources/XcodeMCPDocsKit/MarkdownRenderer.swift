import Foundation

/// Formats the tool list as Markdown. Also used for a single tool's details.
public struct MarkdownRenderer {
    public init() {}

    public func render(_ catalog: ToolCatalog) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = .current

        var lines = [
            "# Xcode MCP Tools",
            "",
            "| Item | Value |",
            "| --- | --- |",
            "| Server | \(catalog.serverInfo.name) \(catalog.serverInfo.version) |",
            "| MCP protocol | \(catalog.protocolVersion) |",
            "| Tools | \(catalog.tools.count) |",
            "| Fetched | \(formatter.string(from: catalog.fetchedAt)) |",
            "| mcpbridge | `\(catalog.bridgePath)` |",
            "",
        ]

        for group in catalog.tools.groupedByCategory() {
            lines.append("## \(group.category.name)")
            lines.append("")
            for tool in group.tools {
                lines.append(render(tool, headingLevel: 3))
            }
        }
        return lines.joined(separator: "\n")
    }

    public func render(_ tool: Tool, headingLevel: Int = 1) -> String {
        let heading = String(repeating: "#", count: headingLevel)
        var lines = ["\(heading) \(tool.name)", ""]

        if let description = tool.description, !description.isEmpty {
            lines.append(description)
            lines.append("")
        }

        lines.append(contentsOf: table(tool.inputSchemaTree, title: "Input", emptyMessage: "No parameters"))
        lines.append(contentsOf: table(tool.outputSchemaTree, title: "Output", emptyMessage: "Not defined"))
        return lines.joined(separator: "\n")
    }

    private func table(_ node: SchemaNode?, title: String, emptyMessage: String) -> [String] {
        guard let node, node.hasChildren else {
            return ["**\(title)**: \(emptyMessage)", ""]
        }
        var lines = [
            "**\(title)**",
            "",
            "| Name | Type | Required | Description |",
            "| --- | --- | --- | --- |",
        ]
        lines.append(contentsOf: node.children.flatMap { rows($0, depth: 0) })
        lines.append("")
        return lines
    }

    private func rows(_ node: SchemaNode, depth: Int) -> [String] {
        let indent = String(repeating: "&nbsp;&nbsp;", count: depth)
        var description = node.description ?? ""
        if !node.enumValues.isEmpty {
            description += " (\(node.enumValues.joined(separator: " / ")))"
        }
        let row = "| \(indent)`\(node.name ?? "-")` | `\(node.type)` | \(node.isRequired ? "✓" : "") "
            + "| \(escapeCell(description)) |"
        return [row] + node.children.flatMap { rows($0, depth: depth + 1) }
    }

    /// Neutralizes newlines and pipes so they cannot break a table cell.
    private func escapeCell(_ text: String) -> String {
        text
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
