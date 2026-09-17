import Foundation

/// Formats the fetched tool list as a self-contained, single-file HTML document.
/// It loads no external CSS, JS, or fonts, so it opens offline.
public struct HTMLRenderer {
    public init() {}

    public func render(_ catalog: ToolCatalog) -> String {
        let groups = catalog.tools.groupedByCategory()
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Xcode MCP Tools</title>
        <style>
        \(Self.stylesheet)
        </style>
        </head>
        <body>
        \(renderHeader(catalog, groups: groups))
        <main>
        \(groups.map(renderSection).joined(separator: "\n"))
        <p id="empty" hidden>No tools match.</p>
        </main>
        <script>
        \(Self.script)
        </script>
        </body>
        </html>
        """
    }
}

// MARK: - Parts

private extension HTMLRenderer {
    func renderHeader(_ catalog: ToolCatalog, groups: [(category: ToolCategory, tools: [Tool])]) -> String {
        let chips = ([("All", "")] + groups.map { ($0.category.name, $0.category.name) })
            .enumerated()
            .map { index, chip in
                """
                <button class="chip\(index == 0 ? " selected" : "")" data-category="\(escape(chip.1))">\(escape(chip.0))</button>
                """
            }
            .joined(separator: "\n")

        return """
        <header>
        <h1>Xcode MCP Tools</h1>
        <dl class="meta">
        \(renderXcodeMeta(catalog))
        <div><dt>Server</dt><dd>\(escape(catalog.serverInfo.name)) \(escape(catalog.serverInfo.version))</dd></div>
        <div><dt>MCP protocol</dt><dd>\(escape(catalog.protocolVersion))</dd></div>
        <div><dt>Tools</dt><dd><span id="count">\(catalog.tools.count)</span> / \(catalog.tools.count)</dd></div>
        </dl>
        <input id="search" type="search" placeholder="Filter by tool name or description" autocomplete="off">
        <div class="chips">
        \(chips)
        </div>
        </header>
        """
    }

    /// Renders the Xcode version/build rows, or nothing when neither could be resolved.
    func renderXcodeMeta(_ catalog: ToolCatalog) -> String {
        guard catalog.xcodeVersion != nil || catalog.xcodeBuild != nil else { return "" }
        return """
        <div><dt>Xcode version</dt><dd>\(escape(catalog.xcodeVersion ?? "Unknown"))</dd></div>
        <div><dt>Build</dt><dd>\(escape(catalog.xcodeBuild ?? "Unknown"))</dd></div>
        """
    }

    func renderSection(_ group: (category: ToolCategory, tools: [Tool])) -> String {
        """
        <details class="category" data-category="\(escape(group.category.name))" open>
        <summary><span class="category-name">\(escape(group.category.name))</span><span class="badge">\(group.tools.count)</span></summary>
        \(group.tools.map(renderTool).joined(separator: "\n"))
        </details>
        """
    }

    func renderTool(_ tool: Tool) -> String {
        let haystack = "\(tool.name) \(tool.description ?? "")".lowercased()
        return """
        <article class="tool" id="tool-\(escape(tool.name))" data-search="\(escape(haystack))">
        <h3 class="tool-heading">
        <a class="tool-name" href="#tool-\(escape(tool.name))">\(escape(tool.name))</a>
        <span class="tool-summary">\(escape(tool.summary))</span>
        </h3>
        <div class="body">
        \(renderDescription(tool))
        \(renderSchema(tool.inputSchemaTree, title: "Input", emptyMessage: "No parameters"))
        \(renderSchema(tool.outputSchemaTree, title: "Output", emptyMessage: "Not defined"))
        \(renderRawJSON(tool))
        </div>
        </article>
        """
    }

    func renderDescription(_ tool: Tool) -> String {
        guard let description = tool.description, !description.isEmpty else { return "" }
        return #"<div class="desc">\#(escape(description))</div>"#
    }

    func renderSchema(_ node: SchemaNode?, title: String, emptyMessage: String) -> String {
        guard let node, node.hasChildren else {
            return """
            <h4>\(escape(title))</h4>
            <p class="empty">\(escape(emptyMessage))</p>
            """
        }
        let rows = node.children.flatMap { flatten($0, depth: 0) }.joined(separator: "\n")
        return """
        <h4>\(escape(title))</h4>
        <table>
        <thead><tr><th>Name</th><th>Type</th><th>Required</th><th>Description</th></tr></thead>
        <tbody>
        \(rows)
        </tbody>
        </table>
        """
    }

    /// Flattens a nested schema into rows indented by their depth.
    func flatten(_ node: SchemaNode, depth: Int) -> [String] {
        let enumNote = node.enumValues.isEmpty
            ? ""
            : #"<div class="enum">\#(escape(node.enumValues.joined(separator: " / ")))</div>"#
        let row = """
        <tr>
        <td class="name" style="padding-left: \(12 + depth * 18)px"><code>\(escape(node.name ?? "-"))</code></td>
        <td class="type"><code>\(escape(node.type))</code></td>
        <td class="required">\(node.isRequired ? "Required" : "")</td>
        <td class="desc-cell">\(escape(node.description ?? ""))\(enumNote)</td>
        </tr>
        """
        return [row] + node.children.flatMap { flatten($0, depth: depth + 1) }
    }

    func renderRawJSON(_ tool: Tool) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(tool) else { return "" }
        return """
        <details class="raw">
        <summary>Raw JSON</summary>
        <pre>\(escape(String(decoding: data, as: UTF8.self)))</pre>
        </details>
        """
    }

    func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - CSS / JS

private extension HTMLRenderer {
    static let stylesheet = """
    :root {
      --bg: #ffffff;
      --surface: #f6f7f9;
      --border: #d8dce2;
      --text: #1c1e21;
      --muted: #666d78;
      --accent: #0b6bcb;
      --accent-soft: #e5f0fb;
      --required: #b3261e;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #16181c;
        --surface: #1e2126;
        --border: #333840;
        --text: #e6e8eb;
        --muted: #9aa2ad;
        --accent: #6fb3f2;
        --accent-soft: #1d2c3d;
        --required: #f2887f;
      }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", sans-serif;
      font-size: 15px;
      line-height: 1.7;
    }
    code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
    header {
      position: sticky;
      top: 0;
      z-index: 10;
      background: var(--bg);
      border-bottom: 1px solid var(--border);
      padding: 20px 24px 12px;
    }
    h1 { margin: 0 0 12px; font-size: 22px; }
    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 4px 24px;
      margin: 0 0 14px;
      font-size: 13px;
    }
    .meta div { display: flex; gap: 6px; }
    .meta dt { color: var(--muted); margin: 0; }
    .meta dd { margin: 0; }
    #search {
      width: 100%;
      padding: 10px 12px;
      font-size: 15px;
      color: var(--text);
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
    }
    #search:focus { outline: 2px solid var(--accent); outline-offset: -1px; }
    .chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
    .chip {
      padding: 5px 12px;
      font-size: 13px;
      color: var(--muted);
      background: transparent;
      border: 1px solid var(--border);
      border-radius: 999px;
      cursor: pointer;
    }
    .chip:hover { color: var(--text); }
    .chip.selected {
      color: var(--accent);
      background: var(--accent-soft);
      border-color: var(--accent);
    }
    main { padding: 20px 24px 64px; }
    .category { margin-bottom: 28px; }
    .category > summary {
      display: flex;
      align-items: center;
      gap: 8px;
      position: sticky;
      top: 0;
      padding: 8px 0;
      margin-bottom: 10px;
      background: var(--bg);
      font-size: 16px;
      font-weight: 600;
      color: var(--muted);
      cursor: pointer;
      list-style: none;
      border-bottom: 1px solid var(--border);
    }
    .category > summary::-webkit-details-marker { display: none; }
    .category > summary::before {
      content: "▾";
      font-size: 11px;
      width: 12px;
    }
    .category:not([open]) > summary::before { content: "▸"; }
    .category:not([open]) > summary { margin-bottom: 0; }
    .category > summary:hover { color: var(--text); }
    .badge {
      padding: 1px 8px;
      font-size: 12px;
      font-weight: 400;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 999px;
    }
    .tool {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      margin-bottom: 10px;
      padding: 12px 16px 16px;
    }
    .tool-heading {
      display: flex;
      flex-wrap: wrap;
      align-items: baseline;
      gap: 4px 12px;
      margin: 0;
    }
    .tool-name {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 15px;
      font-weight: 600;
      color: var(--text);
      text-decoration: none;
    }
    .tool-name:hover { color: var(--accent); }
    .tool-summary { flex: 1; min-width: 200px; font-size: 13px; font-weight: 400; color: var(--muted); }
    .body { font-size: 15px; }
    .desc {
      white-space: pre-wrap;
      font-size: 15px;
      margin: 10px 0;
    }
    h4 { margin: 18px 0 6px; font-size: 13px; color: var(--muted); }
    .empty { margin: 0; font-size: 13px; color: var(--muted); }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { text-align: left; vertical-align: top; padding: 7px 10px; border-top: 1px solid var(--border); }
    th { color: var(--muted); font-weight: 600; }
    td.name code { font-weight: 600; }
    td.type code { color: var(--accent); }
    td.required { color: var(--required); white-space: nowrap; }
    td.desc-cell { width: 55%; white-space: pre-wrap; }
    .enum { margin-top: 3px; color: var(--muted); }
    .raw { margin-top: 16px; }
    .raw > summary { font-size: 13px; color: var(--muted); cursor: pointer; }
    .raw pre {
      overflow-x: auto;
      padding: 12px;
      margin: 8px 0 0;
      font-size: 12px;
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 6px;
    }
    #empty { color: var(--muted); font-size: 15px; }
    """

    static let script = """
    const search = document.getElementById('search');
    const chips = Array.from(document.querySelectorAll('.chip'));
    const sections = Array.from(document.querySelectorAll('.category'));
    const count = document.getElementById('count');
    const empty = document.getElementById('empty');
    let category = '';

    // Remember how the reader left each category, and restore that once searching is over.
    for (const section of sections) {
      section.dataset.userOpen = 'true';
      section.querySelector('summary').addEventListener('click', () => {
        section.dataset.userOpen = section.open ? 'false' : 'true';
      });
    }

    function apply() {
      const query = search.value.trim().toLowerCase();
      let visible = 0;
      for (const section of sections) {
        const inCategory = !category || section.dataset.category === category;
        let shown = 0;
        for (const tool of section.querySelectorAll('.tool')) {
          const match = inCategory && (!query || tool.dataset.search.includes(query));
          tool.hidden = !match;
          if (match) { shown++; }
        }
        section.hidden = shown === 0;
        // Open matching categories while searching; restore the previous state once cleared.
        section.open = query ? shown > 0 : section.dataset.userOpen !== 'false';
        visible += shown;
      }
      count.textContent = visible;
      empty.hidden = visible !== 0;
    }

    search.addEventListener('input', apply);
    for (const chip of chips) {
      chip.addEventListener('click', () => {
        chips.forEach((other) => other.classList.toggle('selected', other === chip));
        category = chip.dataset.category;
        apply();
      });
    }
    // When opened with an anchor, open the category holding that tool and scroll to it.
    if (location.hash) {
      const target = document.getElementById(location.hash.slice(1));
      if (target) {
        const section = target.closest('.category');
        if (section) {
          section.open = true;
          section.dataset.userOpen = 'true';
        }
        target.scrollIntoView();
      }
    }
    """
}
