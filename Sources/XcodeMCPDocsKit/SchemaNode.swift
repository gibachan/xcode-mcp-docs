import Foundation

/// A JSON Schema normalized into a shape that is easy to display.
public struct SchemaNode: Equatable {
    /// The property name. nil for the root and for array elements.
    public let name: String?
    /// The type formatted for display, such as `string` or `array<object>`.
    public let type: String
    public let isRequired: Bool
    public let description: String?
    public let enumValues: [String]
    /// Properties of the object, or of the array's elements.
    public let children: [SchemaNode]

    public var hasChildren: Bool { !children.isEmpty }
}

public extension SchemaNode {
    /// Converts the root of a schema (usually `type: object`) into a tree.
    static func make(from schema: JSONValue?, name: String? = nil, isRequired: Bool = false) -> SchemaNode? {
        guard let schema, case .object = schema else { return nil }

        let required = Set(schema["required"]?.arrayValue?.compactMap(\.stringValue) ?? [])
        let rawType = schema["type"]?.stringValue ?? (schema["properties"] != nil ? "object" : "any")

        // Show arrays down to their element type, and expand the element's properties as children.
        var displayType = rawType
        var propertySource = schema
        if rawType == "array", let items = schema["items"] {
            let itemType = items["type"]?.stringValue ?? "any"
            displayType = "array<\(itemType)>"
            propertySource = items
        }

        let itemRequired = Set(propertySource["required"]?.arrayValue?.compactMap(\.stringValue) ?? [])
        let children = (propertySource["properties"]?.objectValue ?? [:])
            .sorted { lhs, rhs in
                // Required ones first, and by name within each group.
                let lhsRequired = itemRequired.contains(lhs.key)
                let rhsRequired = itemRequired.contains(rhs.key)
                if lhsRequired != rhsRequired { return lhsRequired }
                return lhs.key < rhs.key
            }
            .compactMap { key, value in
                make(from: value, name: key, isRequired: itemRequired.contains(key))
            }

        return SchemaNode(
            name: name,
            type: displayType,
            isRequired: isRequired || required.contains(name ?? ""),
            description: schema["description"]?.stringValue,
            enumValues: schema["enum"]?.arrayValue?.compactMap(\.stringValue) ?? [],
            children: children
        )
    }
}

public extension Tool {
    var inputSchemaTree: SchemaNode? { SchemaNode.make(from: inputSchema) }
    var outputSchemaTree: SchemaNode? { SchemaNode.make(from: outputSchema) }
}
