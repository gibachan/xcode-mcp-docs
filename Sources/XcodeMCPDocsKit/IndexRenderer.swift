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
                let label = document.isBeta ? "Xcode \(document.version) (Beta)" : "Xcode \(document.version)"
                return """
                <option value="\(escape(document.fileName))"\(index == 0 ? " selected" : "")>\(escape(label))</option>
                """
            }
            .joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Xcode MCP Docs</title>
        <style>
        \(Self.stylesheet)
        </style>
        </head>
        <body>
        <header>
        <div class="title-group">
        <h1>Xcode MCP Docs</h1>
        <p class="subtitle">docs for the tools xcode's built-in mcp server exposes, by version</p>
        </div>
        <select id="version" aria-label="Xcode version">
        \(options)
        </select>
        </header>
        <iframe id="doc" src="\(escape(first.fileName))" title="Xcode MCP Docs"></iframe>
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
    <title>Xcode MCP Docs</title>
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
      --muted: #6e7480;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #16181c;
        --border: #333840;
        --text: #e6e8eb;
        --muted: #9aa1ac;
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
    .title-group { display: flex; flex-direction: column; gap: 2px; }
    h1 { margin: 0; font-size: 15px; font-weight: 600; }
    .subtitle { margin: 0; font-size: 12px; color: var(--muted); }
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

    function toolAnchor() {
      const hash = window.location.hash.slice(1);
      if (!hash) return null;
      return hash.startsWith('tool-') ? hash : `tool-${hash}`;
    }

    function loadFrame() {
      const anchor = toolAnchor();
      frame.src = anchor ? `${select.value}#${anchor}` : select.value;
    }

    select.addEventListener('change', loadFrame);
    window.addEventListener('hashchange', loadFrame);
    loadFrame();
    """
}
