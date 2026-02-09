import AppKit

enum SyntaxLanguage: String, CaseIterable, Identifiable {
    case markdown
    case javascript
    case typescript
    case php
    case python
    case ruby
    case html
    case css
    case xml
    case toml
    case json
    case plainText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .php: return "PHP"
        case .python: return "Python"
        case .ruby: return "Ruby"
        case .html: return "HTML"
        case .css: return "CSS"
        case .xml: return "XML"
        case .toml: return "TOML"
        case .json: return "JSON"
        case .plainText: return "Plain Text"
        }
    }

    static func from(fileURL: URL?) -> SyntaxLanguage {
        guard let ext = fileURL?.pathExtension.lowercased() else {
            return .plainText
        }

        switch ext {
        case "md": return .markdown
        case "js": return .javascript
        case "ts": return .typescript
        case "php": return .php
        case "py": return .python
        case "rb": return .ruby
        case "html", "htm": return .html
        case "css": return .css
        case "xml": return .xml
        case "toml": return .toml
        case "json": return .json
        default: return .plainText
        }
    }
}

struct SyntaxRule {
    let regex: NSRegularExpression
    let color: NSColor
}

final class SyntaxHighlighter {
    static let shared = SyntaxHighlighter()
    static let maxHighlightedCharacters = 2_000_000
    private static let contextPadding = 2_048

    private let baseFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    private let baseColor = NSColor.labelColor

    private let keywordColor = NSColor.systemIndigo
    private let typeColor = NSColor.systemTeal
    private let stringColor = NSColor.systemPurple
    private let numberColor = NSColor.systemBlue
    private let commentColor = NSColor.systemGreen
    private let tagColor = NSColor.systemBlue
    private let attributeColor = NSColor.systemPurple

    private var cache: [SyntaxLanguage: [SyntaxRule]] = [:]

    private init() {}

    func shouldHighlight(textLength: Int) -> Bool {
        textLength <= Self.maxHighlightedCharacters
    }

    func apply(to storage: NSTextStorage, language: SyntaxLanguage, in requestedRange: NSRange? = nil) {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }
        let range = effectiveRange(for: requestedRange, in: fullRange)

        storage.beginEditing()
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: baseColor
        ], range: range)

        guard language != .plainText else {
            storage.endEditing()
            return
        }

        let rules = rulesForLanguage(language)
        let source = storage.string

        for rule in rules {
            rule.regex.enumerateMatches(in: source, options: [], range: range) { match, _, _ in
                guard let match else { return }
                storage.addAttribute(.foregroundColor, value: rule.color, range: match.range)
            }
        }

        storage.endEditing()
    }

    private func effectiveRange(for requestedRange: NSRange?, in fullRange: NSRange) -> NSRange {
        guard let requestedRange else { return fullRange }
        let start = max(requestedRange.location - Self.contextPadding, 0)
        let end = min(NSMaxRange(requestedRange) + Self.contextPadding, NSMaxRange(fullRange))
        return NSRange(location: start, length: max(end - start, 0))
    }

    private func rulesForLanguage(_ language: SyntaxLanguage) -> [SyntaxRule] {
        if let cached = cache[language] {
            return cached
        }

        let rules: [(String, NSRegularExpression.Options, NSColor)]

        switch language {
        case .javascript, .typescript:
            rules = [
                ("\"(?:\\\\.|[^\"\\\\])*\"", [], stringColor),
                ("'(?:\\\\.|[^'\\\\])*'", [], stringColor),
                ("\\b\\d+(?:\\.\\d+)?\\b", [], numberColor),
                ("\\b(const|let|var|function|return|if|else|for|while|switch|case|break|continue|class|extends|new|import|export|from|try|catch|finally|throw|async|await|type|interface|enum|implements)\\b", [], keywordColor),
                ("\\b(Array|Object|Promise|Map|Set|Date|String|Number|Boolean)\\b", [], typeColor),
                ("//.*", [], commentColor),
                ("/\\*([\\s\\S]*?)\\*/", [], commentColor)
            ]
        case .php:
            rules = [
                ("\"(?:\\\\.|[^\"\\\\])*\"", [], stringColor),
                ("'(?:\\\\.|[^'\\\\])*'", [], stringColor),
                ("\\$[A-Za-z_][A-Za-z0-9_]*", [], attributeColor),
                ("\\b\\d+(?:\\.\\d+)?\\b", [], numberColor),
                ("\\b(function|class|public|private|protected|static|new|return|if|elseif|else|for|foreach|while|do|switch|case|break|continue|try|catch|finally|throw|namespace|use|extends|implements|interface|trait|const|echo)\\b", [], keywordColor),
                ("//.*", [], commentColor),
                ("#.*", [], commentColor),
                ("/\\*([\\s\\S]*?)\\*/", [], commentColor)
            ]
        case .python:
            rules = [
                ("\"(?:\\\\.|[^\"\\\\])*\"", [], stringColor),
                ("'(?:\\\\.|[^'\\\\])*'", [], stringColor),
                ("\\b\\d+(?:\\.\\d+)?\\b", [], numberColor),
                ("\\b(def|class|return|if|elif|else|for|while|try|except|finally|raise|with|as|import|from|pass|break|continue|lambda|yield|async|await|global|nonlocal|in|is|not|and|or|None|True|False)\\b", [], keywordColor),
                ("#.*", [], commentColor),
                ("\"\"\"([\\s\\S]*?)\"\"\"", [], commentColor),
                ("'''([\\s\\S]*?)'''", [], commentColor)
            ]
        case .ruby:
            rules = [
                ("\"(?:\\\\.|[^\"\\\\])*\"", [], stringColor),
                ("'(?:\\\\.|[^'\\\\])*'", [], stringColor),
                ("\\b\\d+(?:\\.\\d+)?\\b", [], numberColor),
                ("\\b(def|class|module|end|if|elsif|else|unless|while|until|for|in|do|begin|rescue|ensure|return|yield|super|self|require|include|extend|attr_reader|attr_writer|attr_accessor|true|false|nil)\\b", [], keywordColor),
                ("@[A-Za-z_][A-Za-z0-9_]*", [], attributeColor),
                ("#.*", [], commentColor)
            ]
        case .html, .xml:
            rules = [
                ("<\\/?[A-Za-z0-9:_-]+", [], tagColor),
                ("\\b[A-Za-z0-9:_-]+(?=\\=)", [], attributeColor),
                ("\"(?:\\\\.|[^\"\\\\])*\"", [], stringColor),
                ("<!--([\\s\\S]*?)-->", [], commentColor)
            ]
        case .css:
            rules = [
                ("^[^\\n\\{]+(?=\\{)", [.anchorsMatchLines], keywordColor),
                ("\\b[A-Za-z-]+(?=\\s*:)", [], attributeColor),
                ("\"(?:\\\\.|[^\"\\\\])*\"", [], stringColor),
                ("\\b\\d+(?:\\.\\d+)?(px|em|rem|%|vh|vw|deg|s|ms)?\\b", [], numberColor),
                ("/\\*([\\s\\S]*?)\\*/", [], commentColor)
            ]
        case .markdown:
            rules = [
                ("^#{1,6}\\s+.*", [.anchorsMatchLines], keywordColor),
                ("`[^`]+`", [], stringColor),
                ("\\*\\*([^*]+)\\*\\*", [], typeColor),
                ("\\*([^*]+)\\*", [], typeColor),
                ("\\[[^\\]]+\\]\\([^\\)]+\\)", [], tagColor)
            ]
        case .toml:
            rules = [
                ("^\\s*\\[[^\\]]+\\]", [.anchorsMatchLines], keywordColor),
                ("^[A-Za-z0-9_.-]+(?=\\s*=)", [.anchorsMatchLines], attributeColor),
                ("\"(?:\\\\.|[^\"\\\\])*\"", [], stringColor),
                ("\\b(true|false)\\b", [], keywordColor),
                ("\\b\\d+(?:\\.\\d+)?\\b", [], numberColor),
                ("^\\s*#.*", [.anchorsMatchLines], commentColor)
            ]
        case .json:
            rules = [
                ("\"([^\"\\\\]|\\\\.)*\"(?=\\s*:)", [], attributeColor),
                ("\"(?:\\\\.|[^\"\\\\])*\"", [], stringColor),
                ("\\b(true|false|null)\\b", [], keywordColor),
                ("\\b\\d+(?:\\.\\d+)?\\b", [], numberColor)
            ]
        case .plainText:
            rules = []
        }

        let compiled = rules.compactMap { pattern, options, color -> SyntaxRule? in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                return nil
            }
            return SyntaxRule(regex: regex, color: color)
        }

        cache[language] = compiled
        return compiled
    }
}
