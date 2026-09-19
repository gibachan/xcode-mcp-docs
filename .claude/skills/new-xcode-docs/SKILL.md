---
name: new-xcode-docs
description: >-
  End-to-end workflow for documenting a newly installed Xcode: runs
  `xcode-mcp-docs generate` to produce the English tool docs, then produces
  the matching Japanese translation and rebuilds Documentations/index.html.
  Use this whenever the user installs a new Xcode (including betas) and
  wants its MCP tool docs added — including casual phrasings like "新しい
  Xcodeを入れたのでドキュメントを作って" or "generate docs for the new Xcode,
  Japanese too" — even if they only ask for one language, since the default
  is to produce both. For translating an already-generated English doc on
  its own (no new Xcode involved), use translate-docs-ja instead.
---

# Document a newly installed Xcode

This is the umbrella workflow for what's otherwise two separate manual
steps: generating the English docs with the CLI, then translating them.
Doing them together also unlocks a shortcut (Step 3) that the translation
step alone can't assume: a new Xcode point release very often ships the
*exact same* MCP tool set as the version generated right before it, in
which case translation is a copy-and-patch instead of a re-translation.

## Step 1 — Identify the target Xcode

- If the user names a path or app (e.g. `/Applications/Xcode-27.1.0-beta.app`),
  use it directly.
- Otherwise, list `/Applications/Xcode*.app` and ask which one, or infer it
  from context (e.g. "the beta I just installed" → the newest-looking one
  not already covered by a file in `Documentations/`).
- Confirm `.build/release/xcode-mcp-docs` exists and is reasonably current;
  if not, `swift build -c release` first (see root `CLAUDE.md`).

## Step 2 — Generate the English docs

```sh
.build/release/xcode-mcp-docs generate --xcode <path-to-Xcode.app>
```

Run without `-o` so it writes to the default
`Documentations/xcode-<version>-mcp-tools.html` and automatically rewrites
`Documentations/index.html`'s version switcher. Note the exact version
string the tool prints (e.g. `27.1`, `27.2 (Beta)`) — you'll need it in
Step 3. If the command errors, it's almost always one of the two Xcode-
generation quirks documented in root `CLAUDE.md` (headless MCP server on
27+, GUI-and-agent-approval requirement on 26.x) — read that file's
Architecture section rather than guessing.

## Step 3 — Translate to Japanese (with a shortcut)

Before doing a full translation pass, check whether this new version's tool
content is identical to a version that's already translated — new betas
frequently ship no tool-schema changes at all, only a version/build/server
bump:

```sh
diff <(sed -E 's/(Xcode version|Build|Server)<\/dt><dd>[^<]*/\1<\/dt><dd>/' Documentations/xcode-<new>-mcp-tools.html) \
     <(sed -E 's/(Xcode version|Build|Server)<\/dt><dd>[^<]*/\1<\/dt><dd>/' Documentations/xcode-<other>-mcp-tools.html)
```

(Pick `<other>` as the most recently generated version before this one —
check `Documentations/*.html` modification order or the version-sort in
`index.html`.)

- **If that diff is empty** (only the `<dt>Xcode version</dt><dd>...</dd>`
  etc. lines differ) **and** `Documentations/ja/xcode-<other>-mcp-tools.html`
  already exists: copy it —
  `cp Documentations/ja/xcode-<other>-mcp-tools.html Documentations/ja/xcode-<new>-mcp-tools.html`
  — then edit *only* the three `<dt>Xcode version</dt>`, `<dt>ビルド</dt>`,
  `<dt>サーバー</dt>` `<dd>` values to match the new English file's values
  from Step 2. Nothing else should change; verify with the same normalized
  diff against the English file before and after your edit to be sure you
  didn't touch anything else. This is far faster and less error-prone than
  re-translating identical prose.
- **Otherwise** (content actually differs, or no prior Japanese translation
  exists to copy from): invoke the `translate-docs-ja` skill for this
  specific file and let it do the full translation — don't hand-translate
  it yourself here, that skill has the detailed rules (what never to
  translate, the fixed UI-string glossary, how `tool-summary` and
  `data-search` are derived, etc.).

## Step 4 — Rebuild the index

If you took the copy-and-patch shortcut in Step 3, `Documentations/index.html`
still needs rebuilding to pick up the new `ja/` file (Step 2's `generate`
only knew about the English file at the time it ran):

```sh
.build/release/xcode-mcp-docs reindex
```

(If you invoked `translate-docs-ja`, it already does this as its own Step 3
— don't run it twice, just confirm via `git diff Documentations/index.html`
that the new version now has `data-ja="1"`.)

## Step 5 — Verify

- `git status` — expect one new `Documentations/xcode-<new>-mcp-tools.html`,
  one new `Documentations/ja/xcode-<new>-mcp-tools.html`, and a modified
  `Documentations/index.html` (new `<option>` with `data-ja="1"`, inserted
  in version order).
- Open `Documentations/index.html` (serve the `Documentations/` directory
  locally to avoid `file://` iframe restrictions) and confirm the new
  version appears in the switcher, loads in both English and 日本語, and
  that search/category filtering still work.
- Do not commit unless the user asks — leave the new files staged/unstaged
  for their review.
