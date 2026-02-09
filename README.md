# MarqueeTextEdit

Minimal native macOS text editor with basic syntax highlighting for:
- Markdown, JavaScript, TypeScript, HTML, CSS, XML, TOML, JSON

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

## Notes

- Uses a document-based app (`DocumentGroup`) with native macOS tabbing support.
- Follows system color mode and uses native controls.
- Duplicate command creates a copy of the current document (or a temp copy for untitled files).
