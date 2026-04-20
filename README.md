# Marquee

Minimal native macOS text editor with syntax highlighting. TextEdit for code.

Supports Markdown, JavaScript, TypeScript, PHP, Python, Ruby, SQL, HTML, CSS, XML, TOML, JSON, and plain text — with automatic language detection from file extension and a toolbar picker for manual override.

<img width="900" height="701" alt="marquee" src="https://github.com/user-attachments/assets/51b40c9f-8af8-432f-b53d-5e03b4dc06b7" />


## Features

- **Tabs** — native macOS tab bar (`Cmd+T` to open, `Cmd+1`/`2` to switch, `Cmd+Shift+[`/`]` to navigate)
- **Search & Replace** — `Cmd+F` to search, `Cmd+Option+F` for search & replace
- **Duplicate** — `Cmd+D` duplicates the current document
- **Syntax picker** — toolbar dropdown or Syntax menu to switch language manually
- **Demand-driven highlighting** — only highlights visible text for performance
- **Markdown front matter** — recognizes YAML front matter blocks
- **Opens everything** — registers for 100+ file extensions out of the box
- Native document-based app, system color mode, transparent titlebar

## Install

Requires macOS Tahoe (26). Download `Marquee.app.zip` from the [latest release](https://github.com/ymolodtsov/marquee/releases/latest), unzip, and move to `/Applications`.

The app is not signed with an Apple Developer certificate. macOS will quarantine it on first launch. To remove the quarantine flag:

```sh
xattr -d com.apple.quarantine /Applications/Marquee.app
```

Then open normally.

## Build from source

```sh
swift run
```

Or open `MarqueeTextEdit.xcodeproj` in Xcode. To build a release binary:

```sh
swift build -c release
```
