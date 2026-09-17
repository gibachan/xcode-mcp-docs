import Foundation

/// Renders `Documentations/index.html`: a menu that switches between the HTML docs generated
/// for each Xcode version, without loading anything external.
public struct IndexRenderer {
    public init() {}

    /// `documents` should already be in the order to display, e.g.
    /// `VersionedDocument.sortedByVersionDescending(...)`.
    public func render(_ documents: [VersionedDocument]) -> String {
        guard let first = documents.first else { return Self.emptyPage }

        let options = documents.enumerated()
            .map { index, document in
                """
                <option value="\(escape(document.fileName))"\(index == 0 ? " selected" : "")>Xcode \(escape(document.version))</option>
                """
            }
            .joined(separator: "\n")

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
        <header>
        <h1>Xcode MCP Tools</h1>
        <select id="version" aria-label="Xcode version">
        \(options)
        </select>
        </header>
        <iframe id="doc" src="\(escape(first.fileName))" title="Xcode MCP Tools"></iframe>
        <script>
        \(Self.script)
        </script>
        </body>
        </html>
        """
    }

    private func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - Empty state

private extension IndexRenderer {
    static let emptyPage = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <title>Xcode MCP Tools</title>
    </head>
    <body>
    <p>No documentation has been generated yet. Run <code>xcode-mcp-docs generate</code>.</p>
    </body>
    </html>
    """
}

// MARK: - CSS / JS

private extension IndexRenderer {
    static let stylesheet = """
    :root {
      --bg: #ffffff;
      --border: #d8dce2;
      --text: #1c1e21;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #16181c;
        --border: #333840;
        --text: #e6e8eb;
      }
    }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      height: 100%;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", sans-serif;
    }
    header {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 10px 20px;
      border-bottom: 1px solid var(--border);
    }
    h1 { margin: 0; font-size: 15px; font-weight: 600; }
    #version {
      font-size: 14px;
      padding: 5px 8px;
      color: var(--text);
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 6px;
    }
    iframe {
      display: block;
      width: 100%;
      height: calc(100% - 45px);
      border: 0;
    }
    """

    static let script = """
    const select = document.getElementById('version');
    const frame = document.getElementById('doc');
    select.addEventListener('change', () => { frame.src = select.value; });
    """
}
