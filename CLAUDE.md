# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Swift CLI (`xcode-mcp-docs`) that fetches the list of tools exposed by the MCP (Model Context
Protocol) server built into Xcode. Apple publishes no document enumerating these tools — the
definitions live inside Xcode's own binary (`IDEIntelligenceChat.framework`) — so the only
accurate way to obtain them is to ask at runtime, by driving `mcpbridge` (a binary shipped inside
`Xcode.app`) over JSON-RPC and sending `tools/list`.

## Commands

```sh
swift build              # debug build
swift build -c release   # release build (make build does this)
swift test                # run the full test suite (Kit target only; CLI target has no tests)
swift test --filter XcodeLocatorTests            # a single test class
swift test --filter XcodeLocatorTests/testReadsVersionFromBundleInfoPlist  # a single test method

make build         # swift build -c release
make test          # swift test
make install       # builds release, installs to $(PREFIX)/bin (default ~/.local/bin)
make clean         # swift package clean
make generate-all  # runs `generate` against every /Applications/Xcode*.app, skipping any
                   # that don't support MCP or aren't Xcode at all (e.g. Xcodes.app)
```

Exercising the CLI itself against a real Xcode requires an actual Xcode installation; there is no
mock for `mcpbridge`. Useful manual invocations:

```sh
.build/release/xcode-mcp-docs list --xcode /Applications/Xcode-27.app
.build/release/xcode-mcp-docs generate --xcode /Applications/Xcode-27.app --open
XCODE_MCP_DOCS_DEBUG=1 .build/release/xcode-mcp-docs list   # logs every JSON-RPC message to stderr
```

## Architecture

Two targets: `XcodeMCPDocsCLI` (executable, thin) and `XcodeMCPDocsKit` (library, all the logic
and all the tests). The CLI depends on the Kit; keep new logic in the Kit so it stays testable
without a real Xcode.

**CLI layer** (`Sources/XcodeMCPDocsCLI`): `XcodeMCPDocs.swift` is the `ArgumentParser` entry
point wiring up four subcommands — `list` (default), `show <tool>`, `generate`, `json`. All four
share `BridgeOptions` (`--xcode`, `--pid`, `--timeout`), whose `makeCatalog()` resolves the target
`mcpbridge` and fetches the tool catalog, then refines low-level errors from the Kit into
actionable ones (e.g. distinguishing "Xcode not running" from "agent unapproved, so the pid-based
request went silent").

**Connecting to Xcode's MCP server** (`XcodeLocator.swift`, `RunningXcode.swift`,
`MCPBridgeClient.swift`): `XcodeLocator.resolveBridge(xcode:)` turns a `--xcode` value (an
`Xcode.app`, its `Developer` dir, or the `mcpbridge` binary itself) — or, if omitted, whatever
`xcode-select` currently points at — into a concrete `mcpbridge` path.
`XcodeLocator.runningXcodes()` shells out to `ps` to list running Xcode GUI processes (used to
list candidates in error messages, and to resolve a `--pid`). `XcodeLocator.xcodeVersion(...)`
reads `CFBundleShortVersionString` from the bundle's `Info.plist`. `MCPBridgeClient` launches
`mcpbridge` as a subprocess and speaks JSON-RPC over its stdin/stdout, in strict order:
`initialize` → `notifications/initialized` → `tools/list`. `ResponseCollector` matches responses
to requests by JSON-RPC `id` and releases the waiter the instant a match arrives — a fixed
`sleep` drops responses on some Xcode versions, so don't reintroduce one. `DebugLog` gates verbose
stderr logging behind the `XCODE_MCP_DOCS_DEBUG` env var.

Two Xcode generations behave differently here, and it shows up throughout `BridgeOptions` and
`XcodeMCPDocsError`: Xcode 27+ runs an MCP server headlessly (no running GUI Xcode needed, and
`MCP_XCODE_PID` is best left unset so the headless service answers); Xcode 26.x's `mcpbridge` only
connects to an already-running GUI Xcode, and naming one via `--pid` goes silently unanswered
(times out) rather than erroring if the agent hasn't been approved in that Xcode's Settings.

**Data model** (`MCPModels.swift`, `JSONValue.swift`, `SchemaNode.swift`): `Tool.inputSchema` /
`outputSchema` are raw JSON Schema, held as the recursive `JSONValue` enum (schemas can take any
shape). `SchemaNode.make(from:)` normalizes a `JSONValue` schema into a display-ready tree
(arrays collapsed to `array<elementType>`, required properties sorted first) that both renderers
walk. `ToolCatalog` bundles everything from one query (bridge path, protocol version, server info,
tools, fetch timestamp) and is itself `Codable` (backs the `json` subcommand).

**Categorization** (`ToolCategory.swift`): Apple publishes no official grouping, so tools are
sorted into categories by a hardcoded name-matching table, in display order; anything unmatched
falls into "Other". When Xcode ships new tools, they land in "Other" until someone adds a rule —
this is expected, not a bug.

**Rendering** (`HTMLRenderer.swift`, `MarkdownRenderer.swift`): Both take a `ToolCatalog` and
produce a complete, self-contained document — the HTML output inlines its own CSS/JS and loads no
external resources so it opens offline. `HTMLRenderer` also renders live search/filter UI in
vanilla JS.

**Per-version output** (`VersionedDocument.swift`, `IndexRenderer.swift`, used from
`GenerateCommand`): `generate`, when `-o` is not given, writes HTML/Markdown to
`Documentations/xcode-<version>-mcp-tools.<ext>` (version read via `XcodeLocator.xcodeVersion`),
and — for HTML written to that default location — rewrites `Documentations/index.html`, a small
switcher (`<select>` + `<iframe>`) over every versioned HTML file already in that directory
(`VersionedDocument` parses/sorts them, newest numeric version first). Passing `-o` explicitly
opts out of both the versioned naming and the index rebuild.

## Tests

`Tests/XcodeMCPDocsKitTests` covers the Kit only (schema flattening, categorization rules, HTML/
Markdown rendering, JSON-RPC response collection/timeout, Xcode bundle/version resolution,
versioned-document parsing/sorting). `Fixtures/tools-list.json` is a captured real `tools/list`
response used across rendering and decoding tests — prefer extending it over hand-rolling new
`Tool` fixtures when a test needs realistic schema shapes.
