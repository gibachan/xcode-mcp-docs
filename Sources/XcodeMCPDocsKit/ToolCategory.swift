import Foundation

/// Tool categories. Apple publishes none, so tools are sorted mechanically by name.
public struct ToolCategory: Equatable, Hashable, Sendable {
    public let name: String

    /// The order defined here is the display order. Anything unmatched falls into `other`.
    static let rules: [(category: ToolCategory, matches: @Sendable (String) -> Bool)] = [
        (ToolCategory(name: "Workspace / Project"), { name in
            ["XcodeOpenWorkspace", "XcodeCloseWorkspace", "XcodeListWorkspaces", "XcodeNewProject",
             "XcodeNewTarget", "XcodeListTargets", "XcodeListTemplates", "XcodeRefreshCodeIssuesInFile"]
                .contains(name)
        }),
        (ToolCategory(name: "File operations"), { name in
            ["XcodeRead", "XcodeWrite", "XcodeUpdate", "XcodeGrep", "XcodeGlob",
             "XcodeLS", "XcodeMV", "XcodeRM", "XcodeMakeDir"].contains(name)
        }),
        (ToolCategory(name: "Build / Run"), { name in
            ["BuildProject", "RunProject", "StopProject", "GetBuildLog", "GetConsoleOutput"].contains(name)
        }),
        (ToolCategory(name: "Schemes / Run destinations"), { name in
            ["XcodeListSchemes", "XcodeSwitchScheme", "XcodeListRunDestinations", "XcodeSwitchRunDestination"]
                .contains(name)
        }),
        (ToolCategory(name: "Testing"), { name in
            ["GetTestList", "RunAllTests", "RunSomeTests", "XcodeListTestPlans", "XcodeSwitchTestPlan"]
                .contains(name)
        }),
        (ToolCategory(name: "Build settings"), { name in
            ["GetTargetBuildSettings", "UpdateTargetBuildSetting", "GetFileCompilerFlags",
             "UpdateFileCompilerFlags", "AddEntitlement", "AddInfoPlist"].contains(name)
        }),
        (ToolCategory(name: "Preview / Debugging"), { name in
            ["RenderPreview", "RunCodeSnippet", "InvokeDebuggerCommand"].contains(name)
        }),
        (ToolCategory(name: "Device interaction"), { $0.hasPrefix("DeviceInteraction") }),
        (ToolCategory(name: "Localization"), { $0.hasPrefix("StringCatalog") || $0 == "LocalizationPlanner" }),
        (ToolCategory(name: "Crashes / Performance"), { name in
            name.hasSuffix("CrashIssues") || name.hasSuffix("CrashIssueLogs")
                || name.contains("FieldPerformance")
        }),
        (ToolCategory(name: "Documentation"), { $0 == "DocumentationSearch" }),
    ]

    static let other = ToolCategory(name: "Other")

    public static func category(for toolName: String) -> ToolCategory {
        rules.first { $0.matches(toolName) }?.category ?? other
    }
}

public extension Array where Element == Tool {
    /// Groups tools by category in display order. Empty categories are left out.
    func groupedByCategory() -> [(category: ToolCategory, tools: [Tool])] {
        let grouped = Dictionary(grouping: self) { ToolCategory.category(for: $0.name) }
        let ordered = ToolCategory.rules.map(\.category) + [ToolCategory.other]
        return ordered.compactMap { category in
            guard let tools = grouped[category], !tools.isEmpty else { return nil }
            return (category, tools.sorted { $0.name < $1.name })
        }
    }
}
