PREFIX ?= $(HOME)/.local

.PHONY: build test install clean

build:
	swift build -c release

test:
	swift test

install: build
	install -d $(PREFIX)/bin
	install .build/release/xcode-mcp-docs $(PREFIX)/bin/xcode-mcp-docs

clean:
	swift package clean
