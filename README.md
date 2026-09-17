# xcode-mcp-docs

A CLI that fetches the list of tools exposed by the MCP (Model Context Protocol) server built
into Xcode.

Apple publishes no document enumerating these tools; the definitions are embedded in Xcode's own
binary (`IDEIntelligenceChat.framework`). The only accurate way to obtain them is to ask at
runtime, by sending the JSON-RPC `tools/list` request to `mcpbridge`.

## Usage

```sh
swift build -c release

# Tools of the currently selected Xcode
xcode-mcp-docs list

# Names only
xcode-mcp-docs list --names-only

# Details of a single tool (tables of parameters and return values)
xcode-mcp-docs show RenderPreview

# Write out HTML and open it in a browser
# (defaults to Documentations/xcode-<version>-mcp-tools.html, and refreshes
# Documentations/index.html so it can switch between every version generated so far)
xcode-mcp-docs generate --open

# Target a specific version
xcode-mcp-docs list --xcode /Applications/Xcode-27.app

# Everything as JSON, including inputSchema / outputSchema
xcode-mcp-docs json -o tools.json
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

- Every tool is expanded from the start; collapsing happens per category (all open by default)
- Incremental search over tool names and descriptions. Matching categories open automatically while
  searching, and the previous open/closed state is restored once the query is cleared
- Filtering by category (classified mechanically from the name; unknown tools land in "other")
- Input and output schemas shown as tables, nesting preserved (required entries first)
- Raw JSON per tool (the only collapsed part) plus an anchor link
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
does not touch the others.

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

## Debugging

Setting `XCODE_MCP_DOCS_DEBUG` prints the messages sent and received, along with the progress of
each wait, to standard error.

```sh
XCODE_MCP_DOCS_DEBUG=1 xcode-mcp-docs list
```

## Implementation notes

- Waiting for responses with a fixed `sleep` drops them on some versions, so `ResponseCollector`
  releases the wait as soon as it sees a matching JSON-RPC `id`
- Requests are sent in the order `initialize` → `notifications/initialized` → `tools/list`, and the
  error distinguishes which of the two waits timed out
- The connection target (`MCP_XCODE_PID`) is not set by default, because naming one goes silent
  while it waits for approval

## Roadmap

- **Phase 1 (done)** — fetching `tools/list`, the `list` / `json` subcommands
- **Phase 2 (done)** — HTML / Markdown output, `show <tool>`
- **Phase 3** — `xcodes` (installed Xcodes and their tool counts), `diff` (differences between
  versions), Skill integration
