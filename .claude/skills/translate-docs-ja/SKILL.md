---
name: translate-docs-ja
description: >-
  Translates this project's generated Xcode MCP tool documentation
  (Documentations/*.html, produced by `xcode-mcp-docs generate`) into Japanese
  and writes it to Documentations/ja/, so index.html's language switcher can
  offer it. Use this whenever the user asks to translate, localize, add
  Japanese, or refresh/update the 日本語 version of these docs — including
  casual phrasings like "日本語版も作って" or "ja docsを更新して" — even if they
  don't name this skill directly or only mention one Xcode version. Do not use
  it for translating unrelated HTML files or for localization work outside
  this repo's generated tool docs.
---

# Translate xcode-mcp-docs into Japanese

## Why this is a skill and not a script

Machine-translating the raw HTML would butcher it: tool names, parameter
names, JSON Schema type strings, and the raw JSON payload must stay in
English exactly as Apple's MCP server returns them, while everything a human
reads — tool descriptions, parameter descriptions, table headers, button
labels — needs natural, idiomatic Japanese, not a literal word-for-word
rendering. That split needs judgment per string, so translate the files
yourself, in place, rather than reaching for an external translation API
(none is configured for this project anyway).

## Step 1 — Decide which file(s) to translate

Each English doc lives at `Documentations/xcode-<version>[-beta]-mcp-tools.html`
(e.g. `xcode-27.0-mcp-tools.html`, `xcode-27.2-beta-mcp-tools.html`).
`Documentations/index.html` itself is NOT translated — its title/subtitle and
the "English"/"日本語" picker are already bilingual by construction in
`Sources/XcodeMCPDocsKit/IndexRenderer.swift`, and it updates automatically in
Step 3.

- List `Documentations/*.html` (excluding `index.html`) and compare against
  `Documentations/ja/`.
- **Default**: translate every English doc that has no `Documentations/ja/<same filename>` yet.
- **If the user names a version** (e.g. "27.2", "the beta one", "26.6"):
  translate only the matching file.
- **If the user asks to refresh/update** the Japanese docs: retranslate every
  English doc regardless of whether a `ja/` file already exists — the English
  source may have changed since the last translation.

## Step 2 — Translate each file

Read the whole English HTML file first (it's one large file — don't read a
truncated prefix and guess at the rest). Then write the Japanese version to
`Documentations/ja/<same filename>`, changing **only** the text described
below and leaving every tag, attribute, `id`, `class`, `data-*` value,
`<script>` block, `<style>` block, and enum-value list byte-for-byte
identical to the English source. This is not a handful of find-and-replace
substitutions — each tool's own English description is free-form prose that
needs translating individually, on top of the fixed UI strings below.

### Never translate or alter

- Tool names (`XcodeListTargets`), parameter/property names
  (`workspaceIdentifier`), and JSON Schema type strings (`string`,
  `array<object>`) — wherever they appear, including inside `<code>`.
- Any `id="..."` or `href="#..."` anchor (`id="tool-XcodeListTargets"`,
  `href="#tool-XcodeListTargets"`) — the index page's `index.html#<ToolName>`
  jump and the language switcher both depend on the Japanese file using the
  *exact same* anchor ids as the English one.
- Every `data-category="..."` attribute, on both the filter `<button>`s and
  the `<details class="category" data-category="...">` sections — the
  page's own JS matches these two by value to drive filtering. Only the
  *visible text* inside the button/`<span class="category-name">` may be
  translated; the attribute itself must stay in English.
- `data-search="..."` — see the note below; you'll edit this one, but not by
  translating it word-for-word.
- The contents of `<details class="raw"><pre>{...}</pre></details>` — this is
  the literal MCP `tools/list` payload. Leave the JSON, including any English
  strings inside it, completely untouched.
- The entire `<script>...</script>` and `<style>...</style>` blocks — copy
  them verbatim. Same for enum-value lists rendered as
  `<div class="enum">value1 / value2</div>` (these are literal accepted
  values, not prose).
- Numbers: version, build, server version, tool counts.

### Do translate

- Every tool's description (`<div class="desc">...</div>`) — free-form prose,
  translate it naturally rather than literally. The one-line summary
  (`<span class="tool-summary">...</span>`) is *not* translated separately —
  see the note below, it's mechanically derived from the description.
- Every parameter/property's description (the `<td class="desc-cell">`
  text) in the Input/Output tables. A few of these cells have a
  `<div class="enum">...</div>` embedded inside them, not just as a sibling —
  translate the surrounding prose but leave that inner div in English like
  any other enum list (see "Never translate" above).
- Inside any of the prose above, if the English text quotes a literal value
  the tool actually accepts or returns (e.g. `'bool'`, `"target"`, a literal
  flag name) — keep that literal untouched, in its original quoting, the same
  as an enum value. Translate the sentence around it, not the literal itself.
- Literal backslash-escape examples describing JSON/regex syntax (e.g. `\d`,
  `\\d`, `’`) — copy these exactly, character for character, rather than
  retyping them; it's easy to silently drop or double a backslash by hand.
- The fixed UI strings and category labels below — use these exact
  translations every time so repeated runs stay consistent across versions:

  | English | Japanese |
  |---|---|
  | Server | サーバー |
  | MCP protocol | MCPプロトコル |
  | Tools | ツール |
  | Xcode version | Xcodeバージョン |
  | Build | ビルド |
  | (Beta) | (ベータ) |
  | Filter by tool name or description | ツール名または説明で絞り込み |
  | No tools match. | 一致するツールがありません。 |
  | All | すべて |
  | Input | 入力 |
  | Output | 出力 |
  | Name (table header) | 名前 |
  | Type (table header) | 型 |
  | Required (table header, and the per-row value) | 必須 |
  | Description (table header) | 説明 |
  | No parameters | パラメータなし |
  | Not defined | 定義なし |
  | Raw JSON | 生のJSON |
  | Workspace / Project | ワークスペース / プロジェクト |
  | File operations | ファイル操作 |
  | Build / Run | ビルド / 実行 |
  | Schemes / Run destinations | スキーム / 実行先 |
  | Testing | テスト |
  | Build settings | ビルド設定 |
  | Preview / Debugging | プレビュー / デバッグ |
  | Device interaction | デバイス操作 |
  | Localization | ローカライズ |
  | Crashes / Performance | クラッシュ / パフォーマンス |
  | Documentation (category) | ドキュメント |
  | Other (category) | その他 |

  A category name appears twice per page (the chip `<button>` and the
  section `<span class="category-name">`) — translate the visible text in
  both places, but leave both `data-category="..."` attributes in English as
  noted above.

### Two values are *derived*, not translated by hand

The English generator computes these mechanically from `tool.description`
(see `Sources/XcodeMCPDocsKit/MCPModels.swift`'s `Tool.summary` and
`Sources/XcodeMCPDocsKit/HTMLRenderer.swift`'s `renderTool`) — do the same
from your *translated* description rather than translating them separately,
or the summary/search text can drift out of sync with the desc:

- `<span class="tool-summary">` = the first line of the (translated)
  description, up to the first line break.
- `data-search="..."` = `tool.name + " " + description`, lowercased. Rewrite
  it as the tool name followed by the translated description, lowercased the
  same way: `data-search="xcodelisttargets <translated description,
  lowercased>"`. Lowercasing only affects ASCII letters, so this is safe even
  though most of the string will be Japanese text — without it, someone
  typing a Japanese search term gets zero results.

### `<title>`

Leave it as-is (`<title>Xcode MCP Tools</title>`) — it's just the browser
tab label, not page content, and there's no need for it to differ between
languages.

## Step 3 — Rebuild the index

After writing the Japanese file(s), refresh `Documentations/index.html` so
its language switcher picks them up. This does not touch Xcode or
`mcpbridge` at all — it only rescans the `Documentations/` directory:

```sh
[ -x .build/release/xcode-mcp-docs ] || swift build -c release
.build/release/xcode-mcp-docs reindex
```

## Step 4 — Verify

Open `Documentations/index.html` (a local static-file server, e.g.
`python3 -m http.server`, in `Documentations/` avoids browser
same-origin restrictions on `file://` iframes) and check:

- The version you translated now offers a "日本語" option next to "English",
  and switching to it loads `Documentations/ja/<file>`.
- The search box still filters correctly when you type an English tool name.
- The category chips still filter correctly (this only works if
  `data-category` attributes were left untouched).
- `index.html#<ToolName>` still jumps to the right tool after switching to
  日本語 (this only works if anchor ids were left untouched).
- Skim a couple of translated descriptions — they should read as natural
  Japanese explanations, not stiff literal translations.
