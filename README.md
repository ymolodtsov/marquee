# Marquee

Minimal native macOS text editor with syntax highlighting. TextEdit for code.

Supports Markdown, JavaScript, TypeScript, PHP, Python, Ruby, SQL, HTML, CSS, XML, TOML, JSON, and plain text — with automatic language detection from file extension and a toolbar picker for manual override.

<img width="2486" height="2018" alt="CleanShot 2026-02-14 at 14 45 25@2x" src="https://github.com/user-attachments/assets/c16e31e6-7e2b-4b0c-a330-e97cfb813b36" />

## Features

- **Tabs** — native macOS tab bar (`Cmd+T` to open, `Cmd+1`/`2` to switch, `Cmd+Shift+[`/`]` to navigate)
- **Search & Replace** — `Cmd+F` to search, `Cmd+Option+F` for search & replace
- **Duplicate** — `Cmd+D` duplicates the current document
- **Syntax picker** — toolbar dropdown or Syntax menu to switch language manually
- **Demand-driven highlighting** — only highlights visible text for performance
- **Markdown front matter** — recognizes YAML front matter blocks
- **Opens everything** — registers for 100+ file extensions out of the box
- Native document-based app, system color mode, transparent titlebar

## Run

Requires macOS Tahoe (26).

```sh
swift run
```

Or open `MarqueeTextEdit.xcodeproj` in Xcode.

## Build

```sh
swift build -c release
```

No signed binary — not paying for an Apple Developer Account for this.
