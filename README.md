# xcode-mcp-docs

A CLI that fetches the list of tools exposed by the MCP (Model Context Protocol) server built
into Xcode, and generates browsable documentation from it — one page per Xcode version.

Apple publishes no document enumerating these tools; the definitions are embedded in Xcode's own
binary (`IDEIntelligenceChat.framework`). The only accurate way to obtain them is to ask at
runtime, by sending the JSON-RPC `tools/list` request to `mcpbridge`.

## Published docs

Generated documentation for each Xcode version's MCP server tools is published at
[gibachan.github.io/xcode-mcp-docs](https://gibachan.github.io/xcode-mcp-docs/) — a switcher menu
over every version generated so far. It's rebuilt automatically from `Documentations/` on every
push to `main` (see `.github/workflows/pages.yml`).

## Usage

```sh
make build

# Tools of the currently selected Xcode
.build/release/xcode-mcp-docs list

# Names only
.build/release/xcode-mcp-docs list --names-only

# Details of a single tool (tables of parameters and return values)
.build/release/xcode-mcp-docs show RenderPreview

# Write out HTML and open it in a browser
# (defaults to Documentations/xcode-<version>-mcp-tools.html, and refreshes
# Documentations/index.html so it can switch between every version generated so far)
.build/release/xcode-mcp-docs generate --open

# Target a specific version
.build/release/xcode-mcp-docs list --xcode /Applications/Xcode-27.app

# Everything as JSON, including inputSchema / outputSchema
.build/release/xcode-mcp-docs json -o tools.json
```

### Subcommands

| Command | What it does |
| --- | --- |
| `list` | Lists tool names with a one-line summary. `--names-only` prints just the names |
| `show <tool>` | Details of a single tool as Markdown. `--json` prints the raw schema |
| `generate` | Writes out documentation. `--format html\|markdown`, `-o <path>` (`-` for stdout), `--open` |
| `json` | The fetched result as-is in JSON. `-o <path>`, `--compact` |

### HTML output

Self-contained in a single file. It loads no external CSS, JS, or fonts, so it opens offline.

- Xcode version and build shown in the header, alongside the MCP server name/version and tool count
- Every tool is expanded from the start; collapsing happens per category (all open by default)
- Incremental search over tool names and descriptions. Matching categories open automatically while
  searching, and the previous open/closed state is restored once the query is cleared
- Filtering by category (classified mechanically from the name; unknown tools land in "other")
- Input and output schemas shown as tables, nesting preserved (required entries first)
- Raw JSON per tool (the only collapsed part) plus an anchor link (`#tool-<Name>`)
- Automatic light / dark switching

### Per-version output and the switcher menu

When `-o` is left unset, `generate` writes to `Documentations/xcode-<version>-mcp-tools.<ext>`,
reading `<version>` (e.g. `26.6`) from the `CFBundleShortVersionString` of the Xcode bundle that
owns the `mcpbridge` being queried. If the version can't be determined (say, `--xcode` pointed
straight at a bare `mcpbridge` binary), it falls back to `Documentations/xcode-mcp-tools.<ext>`.

For HTML output written to that default location, `generate` also rewrites
`Documentations/index.html` — a small menu (`<select>` + `<iframe>`) that switches between every
versioned HTML file already sitting in `Documentations/`, newest version first. Run `generate`
once per Xcode version to build up the switcher; each run only adds/replaces its own file and
does not touch the others. Linking to `index.html#<ToolName>` (e.g. `index.html#RenderPreview`)
jumps straight to that tool in whichever version is currently selected.

Passing `-o` explicitly opts out of both: the file is written exactly where asked, unversioned,
and `index.html` is left alone.

### Options

| Option | Description |
|---|---|
| `--xcode <path>` | The target Xcode: an `Xcode.app`, a `Developer` directory, or the `mcpbridge` binary itself. Defaults to whatever `xcode-select` has selected |
| `--pid <pid>` | Process ID of the Xcode to connect to (`MCP_XCODE_PID`). **Normally leave this unset** (see below) |
| `--timeout <seconds>` | How long to wait for each response (default 30 seconds) |

## Requirements

| Xcode | Requirement |
|---|---|
| 27 and later | Runs headless, so the tools can be fetched without Xcode running (Xcode > Settings > Intelligence must have "Allow external agents to use Xcode tools" enabled) |
| 26.x | `mcpbridge` can only connect to a running Xcode, so the target version must be launched first |

If the Xcode given via `--xcode` is not running and cannot be reached, the error lists the Xcodes
that are currently running.

### Why `--pid` is not used by default

When `MCP_XCODE_PID` names a GUI Xcode in which this agent has not been approved, the `tools/list`
response never comes back and the call times out — it stays silent instead of returning an error.
The headless Xcode Service in Xcode 27, by contrast, responds without approval, so **letting
mcpbridge choose the target is the reliable option**. To pin a version it is enough to select the
corresponding mcpbridge with `--xcode`.
