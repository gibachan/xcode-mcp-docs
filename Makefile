PREFIX ?= $(HOME)/.local

.PHONY: build test install clean generate-all

build:
	swift build -c release

test:
	swift test

install: build
	install -d $(PREFIX)/bin
	install .build/release/xcode-mcp-docs $(PREFIX)/bin/xcode-mcp-docs

clean:
	swift package clean

# Runs `generate` against every Xcode under /Applications. Older Xcodes (or non-Xcode apps that
# happen to match the glob, e.g. Xcodes.app) have no mcpbridge or don't speak MCP, so a failure
# is reported and skipped rather than aborting the rest of the run.
generate-all: build
	@for app in /Applications/Xcode*.app; do \
		echo "==> $$app"; \
		.build/release/xcode-mcp-docs generate --xcode "$$app" || echo "    skipped: $$app does not support MCP"; \
	done
