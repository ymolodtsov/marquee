import AppKit

enum SyntaxLanguage: String, CaseIterable, Identifiable {
    case markdown
    case javascript
    case typescript
    case php
    case python
    case ruby
    case sql
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
        case .sql: return "SQL"
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
        case "md", "mdx": return .markdown
        case "js", "jsx", "mjs", "cjs": return .javascript
        case "ts", "tsx": return .typescript
        case "php": return .php
        case "py": return .python
        case "rb": return .ruby
        case "sql": return .sql
        case "html", "htm", "vue", "svelte", "astro": return .html
        case "css", "scss", "sass", "less": return .css
        case "xml", "svg", "graphql", "gql", "proto": return .xml
        case "toml", "yaml", "yml", "ini", "cfg", "conf", "config", "properties", "env", "editorconfig": return .toml
        case "json", "jsonc": return .json
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
    private static let contextPadding = 4_096

    private let baseFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    private let baseColor = NSColor.labelColor

    // Adaptive colors: (light mode, dark mode)
    // Palette inspired by GitHub, One Dark, and Catppuccin — muted, high-contrast, easy on the eyes.
    private let keywordColor = adaptive(light: (0.66, 0.05, 0.57), dark: (0.77, 0.56, 0.96))       // plum → soft lavender
    private let typeColor = adaptive(light: (0.0, 0.47, 0.46), dark: (0.53, 0.87, 0.85))            // deep teal → mint
    private let stringColor = adaptive(light: (0.64, 0.25, 0.0), dark: (0.90, 0.72, 0.45))          // warm brown → soft amber
    private let numberColor = adaptive(light: (0.0, 0.35, 0.73), dark: (0.56, 0.78, 0.98))          // cobalt → soft sky blue
    private let commentColor = adaptive(light: (0.47, 0.51, 0.55), dark: (0.45, 0.50, 0.55))        // muted gray both modes
    private let tagColor = adaptive(light: (0.84, 0.18, 0.15), dark: (0.95, 0.55, 0.50))            // crimson → soft coral
    private let attributeColor = adaptive(light: (0.75, 0.38, 0.0), dark: (0.95, 0.68, 0.38))       // burnt orange → peach

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1.0)
        }
    }

    private var cache: [SyntaxLanguage: [SyntaxRule]] = [:]

    private init() {}

    func shouldHighlight(textLength: Int) -> Bool {
        textLength <= Self.maxHighlightedCharacters
    }

    func apply(to layoutManager: NSLayoutManager, source: String, language: SyntaxLanguage, in requestedRange: NSRange? = nil) {
        let totalLength = (source as NSString).length
        let fullRange = NSRange(location: 0, length: totalLength)
        guard fullRange.length > 0 else { return }
        let range = effectiveRange(for: requestedRange, in: fullRange)

        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)

        guard language != .plainText else { return }

        let rules = rulesForLanguage(language)

        for rule in rules {
            rule.regex.enumerateMatches(in: source, options: [], range: range) { match, _, _ in
                guard let match else { return }
                layoutManager.addTemporaryAttribute(.foregroundColor, value: rule.color, forCharacterRange: match.range)
            }
        }
    }

    func effectiveRange(for requestedRange: NSRange, totalLength: Int) -> NSRange {
        let start = max(requestedRange.location - Self.contextPadding, 0)
        let end = min(NSMaxRange(requestedRange) + Self.contextPadding, totalLength)
        return NSRange(location: start, length: max(end - start, 0))
    }

    private func effectiveRange(for requestedRange: NSRange?, in fullRange: NSRange) -> NSRange {
        guard let requestedRange else { return fullRange }
        return effectiveRange(for: requestedRange, totalLength: NSMaxRange(fullRange))
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
                ("\"\"\"([\\s\\S]*?)\"\"\"", [], stringColor),
                ("'''([\\s\\S]*?)'''", [], stringColor)
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
        case .sql:
            rules = [
                ("'(?:''|[^'])*'", [], stringColor),
                ("\\b\\d+(?:\\.\\d+)?\\b", [], numberColor),
                ("\\b(SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|SET|DELETE|JOIN|LEFT|RIGHT|INNER|OUTER|FULL|ON|GROUP|BY|ORDER|HAVING|LIMIT|OFFSET|DISTINCT|AS|AND|OR|NOT|NULL|IS|IN|BETWEEN|LIKE|EXISTS|CREATE|ALTER|DROP|TABLE|INDEX|VIEW|TRIGGER|PRIMARY|KEY|FOREIGN|REFERENCES|UNIQUE|DEFAULT|CHECK|CASE|WHEN|THEN|ELSE|END|UNION|ALL)\\b", [.caseInsensitive], keywordColor),
                ("\\b(INT|INTEGER|BIGINT|SMALLINT|DECIMAL|NUMERIC|REAL|FLOAT|DOUBLE|BOOLEAN|CHAR|VARCHAR|TEXT|DATE|TIME|TIMESTAMP|BLOB|JSON)\\b", [.caseInsensitive], typeColor),
                ("--.*", [], commentColor),
                ("/\\*([\\s\\S]*?)\\*/", [], commentColor)
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
                ("\\A---\\n[\\s\\S]*?\\n---", [], commentColor),
                ("^[a-zA-Z_][a-zA-Z0-9_-]*(?=\\s*:)", [.anchorsMatchLines], attributeColor),
                ("^#{1,6}\\s+.*", [.anchorsMatchLines], keywordColor),
                ("```[\\s\\S]*?```", [], stringColor),
                ("`[^`]+`", [], stringColor),
                ("(?<!\\*)\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*(?!\\*)", [], typeColor),
                ("(?<!\\*)\\*(?=\\S)(.+?)(?<=\\S)\\*(?!\\*)", [], typeColor),
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
