# Marquee

Minimal native macOS text editor with basic syntax highlighting for:
- Markdown, JavaScript, TypeScript, HTML, CSS, XML, TOML, JSON

Think "TextEdit for Code".

<img width="2486" height="2018" alt="CleanShot 2026-02-14 at 14 45 25@2x" src="https://github.com/user-attachments/assets/c16e31e6-7e2b-4b0c-a330-e97cfb813b36" />

## Run

```sh
swift run
```

## Xcode

Open `MarqueeTextEdit.xcodeproj` in Xcode.

## Build

```sh
swift build -c release
```

Sorry, there's no binary, no sense in paying for Apple Developer Account just for this. 

## Notes

- Uses a document-based app (`DocumentGroup`) with native macOS tabbing support.
- Follows system color mode and uses native controls.
- Duplicate command creates a copy of the current document (or a temp copy for untitled files).
