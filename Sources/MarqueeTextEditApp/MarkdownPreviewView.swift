import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.loadHTMLString(MarkdownRenderer.render(text), baseURL: nil)
        context.coordinator.lastText = text
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard text != context.coordinator.lastText else { return }
        webView.loadHTMLString(MarkdownRenderer.render(text), baseURL: nil)
        context.coordinator.lastText = text
    }

    final class Coordinator {
        var lastText: String?
    }
}

// MARK: - Markdown Renderer

enum MarkdownRenderer {

    static func render(_ text: String) -> String {
        let clean = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let (fm, body) = parseFrontMatter(clean)
        var content = ""
        if let fm { content += renderFrontMatter(fm) }
        content += renderBody(body)
        return wrapHTML(content)
    }

    // MARK: Front Matter

    private struct FrontMatter {
        let type: String
        let raw: String
    }

    private static func parseFrontMatter(_ text: String) -> (FrontMatter?, String) {
        if text.hasPrefix("---\n") {
            let rest = String(text.dropFirst(4))
            if let range = rest.range(of: "\n---\n") {
                return (FrontMatter(type: "YAML", raw: String(rest[..<range.lowerBound])),
                        String(rest[range.upperBound...]))
            }
            if let range = rest.range(of: "\n---"),
               rest[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (FrontMatter(type: "YAML", raw: String(rest[..<range.lowerBound])), "")
            }
        }

        if text.hasPrefix("+++\n") {
            let rest = String(text.dropFirst(4))
            if let range = rest.range(of: "\n+++\n") {
                return (FrontMatter(type: "TOML", raw: String(rest[..<range.lowerBound])),
                        String(rest[range.upperBound...]))
            }
            if let range = rest.range(of: "\n+++"),
               rest[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (FrontMatter(type: "TOML", raw: String(rest[..<range.lowerBound])), "")
            }
        }

        if text.hasPrefix("{") {
            var depth = 0
            for (idx, char) in text.enumerated() {
                if char == "{" { depth += 1 }
                if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        let endIndex = text.index(text.startIndex, offsetBy: idx + 1)
                        let json = String(text[..<endIndex])
                        var body = String(text[endIndex...])
                        if body.hasPrefix("\n") { body.removeFirst() }
                        return (FrontMatter(type: "JSON", raw: json), body)
                    }
                }
            }
        }

        return (nil, text)
    }

    private static func renderFrontMatter(_ fm: FrontMatter) -> String {
        "<details class=\"frontmatter\" open>\n" +
        "<summary>Front Matter <span class=\"fm-type\">\(fm.type)</span></summary>\n" +
        "<pre><code>\(escapeHTML(fm.raw))</code></pre>\n" +
        "</details>\n"
    }

    // MARK: Body

    private static func renderBody(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var html = ""
        var i = 0
        var paraLines: [String] = []

        func flush() {
            guard !paraLines.isEmpty else { return }
            html += "<p>\(inlineFormat(paraLines.joined(separator: "\n")))</p>\n"
            paraLines.removeAll()
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flush()
                i += 1
                continue
            }

            // Fenced code block
            if trimmed.hasPrefix("```") {
                flush()
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") { i += 1; break }
                    codeLines.append(lines[i])
                    i += 1
                }
                let langAttr = lang.isEmpty ? "" : " class=\"language-\(escapeHTML(lang))\""
                html += "<pre><code\(langAttr)>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>\n"
                continue
            }

            // ATX header
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" })
                let level = hashes.count
                if level <= 6 {
                    let after = String(trimmed.dropFirst(level))
                    if after.hasPrefix(" ") {
                        flush()
                        var headerText = String(after.dropFirst())
                        if let trailingRange = headerText.range(of: "\\s+#+\\s*$", options: .regularExpression) {
                            headerText = String(headerText[..<trailingRange.lowerBound])
                        }
                        let id = headerText.lowercased()
                            .replacingOccurrences(of: " ", with: "-")
                            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                        html += "<h\(level) id=\"\(escapeHTML(id))\">\(inlineFormat(headerText))</h\(level)>\n"
                        i += 1
                        continue
                    }
                }
            }

            // Horizontal rule
            if trimmed.count >= 3 {
                let ruleChars = trimmed.filter { $0 != " " }
                if !ruleChars.isEmpty,
                   Set(ruleChars).count == 1,
                   let first = ruleChars.first,
                   "-*_".contains(first),
                   ruleChars.count >= 3 {
                    flush()
                    html += "<hr>\n"
                    i += 1
                    continue
                }
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                flush()
                var quoteLines: [String] = []
                while i < lines.count {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    if lt.hasPrefix("> ") {
                        quoteLines.append(String(lt.dropFirst(2)))
                    } else if lt.hasPrefix(">") {
                        quoteLines.append(String(lt.dropFirst(1)))
                    } else {
                        break
                    }
                    i += 1
                }
                html += "<blockquote>\(renderBody(quoteLines.joined(separator: "\n")))</blockquote>\n"
                continue
            }

            // Table
            if line.contains("|") && i + 1 < lines.count {
                let nextTrimmed = lines[i + 1].trimmingCharacters(in: .whitespaces)
                let sepOnly = nextTrimmed.filter { $0 != "|" && $0 != "-" && $0 != ":" && $0 != " " }
                if sepOnly.isEmpty && nextTrimmed.contains("-") {
                    flush()
                    let headerCells = splitCells(line)
                    let sepCells = splitCells(lines[i + 1])
                    let aligns = sepCells.map { cell -> String in
                        let t = cell.trimmingCharacters(in: .whitespaces)
                        if t.hasPrefix(":") && t.hasSuffix(":") { return "center" }
                        if t.hasSuffix(":") { return "right" }
                        return "left"
                    }
                    html += "<table>\n<thead>\n<tr>\n"
                    for (j, cell) in headerCells.enumerated() {
                        let a = j < aligns.count ? aligns[j] : "left"
                        html += "<th style=\"text-align:\(a)\">\(inlineFormat(cell.trimmingCharacters(in: .whitespaces)))</th>\n"
                    }
                    html += "</tr>\n</thead>\n<tbody>\n"
                    i += 2
                    while i < lines.count && lines[i].contains("|") &&
                          !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                        let cells = splitCells(lines[i])
                        html += "<tr>\n"
                        for (j, cell) in cells.enumerated() {
                            let a = j < aligns.count ? aligns[j] : "left"
                            html += "<td style=\"text-align:\(a)\">\(inlineFormat(cell.trimmingCharacters(in: .whitespaces)))</td>\n"
                        }
                        html += "</tr>\n"
                        i += 1
                    }
                    html += "</tbody>\n</table>\n"
                    continue
                }
            }

            // Task list
            if isTaskItem(trimmed) {
                flush()
                html += "<ul class=\"task-list\">\n"
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    guard let (checked, content) = parseTaskItem(tl) else { break }
                    let chk = checked ? " checked disabled" : " disabled"
                    html += "<li class=\"task-item\"><input type=\"checkbox\"\(chk)> \(inlineFormat(content))</li>\n"
                    i += 1
                }
                html += "</ul>\n"
                continue
            }

            // Unordered list
            if let content = parseUnorderedItem(trimmed) {
                flush()
                html += "<ul>\n<li>\(inlineFormat(content))</li>\n"
                i += 1
                while i < lines.count {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    if let c = parseUnorderedItem(lt) {
                        html += "<li>\(inlineFormat(c))</li>\n"
                    } else {
                        break
                    }
                    i += 1
                }
                html += "</ul>\n"
                continue
            }

            // Ordered list
            if let content = parseOrderedItem(trimmed) {
                flush()
                html += "<ol>\n<li>\(inlineFormat(content))</li>\n"
                i += 1
                while i < lines.count {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    if let c = parseOrderedItem(lt) {
                        html += "<li>\(inlineFormat(c))</li>\n"
                    } else {
                        break
                    }
                    i += 1
                }
                html += "</ol>\n"
                continue
            }

            paraLines.append(line)
            i += 1
        }

        flush()
        return html
    }

    // MARK: List Helpers

    private static func isTaskItem(_ trimmed: String) -> Bool {
        parseTaskItem(trimmed) != nil
    }

    private static func parseTaskItem(_ trimmed: String) -> (checked: Bool, text: String)? {
        guard trimmed.count > 5,
              let first = trimmed.first,
              "-*+".contains(first) else { return nil }
        let rest = trimmed.dropFirst()
        guard rest.hasPrefix(" [") else { return nil }
        let afterBracket = rest.dropFirst(2)
        guard let checkChar = afterBracket.first,
              " xX".contains(checkChar) else { return nil }
        let afterCheck = afterBracket.dropFirst()
        guard afterCheck.hasPrefix("] ") else { return nil }
        return (checkChar != " ", String(afterCheck.dropFirst(2)))
    }

    private static func parseUnorderedItem(_ trimmed: String) -> String? {
        guard let first = trimmed.first, "-*+".contains(first) else { return nil }
        let rest = trimmed.dropFirst()
        guard rest.hasPrefix(" ") else { return nil }
        if rest.hasPrefix(" [") && rest.count > 4 {
            let ab = rest.dropFirst(2)
            if let ch = ab.first, " xX".contains(ch), ab.dropFirst().hasPrefix("] ") {
                return nil
            }
        }
        return String(rest.dropFirst())
    }

    private static func parseOrderedItem(_ trimmed: String) -> String? {
        guard let first = trimmed.first, first.isNumber else { return nil }
        guard let dotIdx = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }) else { return nil }
        let prefix = trimmed[trimmed.startIndex..<dotIdx]
        guard prefix.allSatisfy(\.isNumber) else { return nil }
        let afterDot = trimmed[trimmed.index(after: dotIdx)...]
        guard afterDot.hasPrefix(" ") else { return nil }
        return String(afterDot.dropFirst())
    }

    // MARK: Inline Formatting

    private static func inlineFormat(_ text: String) -> String {
        var segments: [(text: String, isCode: Bool)] = []
        var remaining = text[...]

        while let openIdx = remaining.firstIndex(of: "`") {
            let before = String(remaining[..<openIdx])
            if !before.isEmpty { segments.append((before, false)) }

            let afterOpen = remaining.index(after: openIdx)
            guard afterOpen < remaining.endIndex else {
                segments.append(("`", false))
                remaining = remaining[remaining.endIndex...]
                break
            }

            if let closeIdx = remaining[afterOpen...].firstIndex(of: "`") {
                segments.append((String(remaining[afterOpen..<closeIdx]), true))
                remaining = remaining[remaining.index(after: closeIdx)...]
            } else {
                segments.append(("`", false))
                remaining = remaining[afterOpen...]
            }
        }
        if !remaining.isEmpty { segments.append((String(remaining), false)) }

        return segments.map { seg in
            seg.isCode
                ? "<code>\(escapeHTML(seg.text))</code>"
                : formatPlain(escapeHTML(seg.text))
        }.joined()
    }

    private static func formatPlain(_ text: String) -> String {
        var r = text
        r = r.replacingOccurrences(of: "!\\[([^\\]]*)\\]\\(([^)]+)\\)",
                                   with: "<img src=\"$2\" alt=\"$1\">",
                                   options: .regularExpression)
        r = r.replacingOccurrences(of: "\\[([^\\]]*)\\]\\(([^)]+)\\)",
                                   with: "<a href=\"$2\">$1</a>",
                                   options: .regularExpression)
        r = r.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*",
                                   with: "<strong><em>$1</em></strong>",
                                   options: .regularExpression)
        r = r.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*",
                                   with: "<strong>$1</strong>",
                                   options: .regularExpression)
        r = r.replacingOccurrences(of: "__(.+?)__",
                                   with: "<strong>$1</strong>",
                                   options: .regularExpression)
        r = r.replacingOccurrences(of: "\\*(.+?)\\*",
                                   with: "<em>$1</em>",
                                   options: .regularExpression)
        r = r.replacingOccurrences(of: "~~(.+?)~~",
                                   with: "<del>$1</del>",
                                   options: .regularExpression)
        return r
    }

    // MARK: Helpers

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func splitCells(_ line: String) -> [String] {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s = String(s.dropFirst()) }
        if s.hasSuffix("|") { s = String(s.dropLast()) }
        return s.components(separatedBy: "|")
    }

    // MARK: HTML Template

    private static func wrapHTML(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        :root { color-scheme: light dark; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
            font-size: 15px;
            line-height: 1.7;
            max-width: 720px;
            margin: 0 auto;
            padding: 32px 40px;
            color: #1d1d1f;
            background: #ffffff;
            -webkit-font-smoothing: antialiased;
        }
        @media (prefers-color-scheme: dark) {
            body { color: #f5f5f7; background: #1d1d1f; }
            a { color: #6cb4ff; }
            blockquote { border-color: #4a9eff; color: #a1a1a6; }
            th { background: rgba(255,255,255,0.04); }
            th, td { border-color: rgba(255,255,255,0.12); }
            .frontmatter { background: rgba(255,255,255,0.04); }
            .fm-type { background: rgba(255,255,255,0.08); }
            pre { background: rgba(255,255,255,0.05); }
            code { background: rgba(255,255,255,0.08); }
            hr { border-color: rgba(255,255,255,0.12); }
        }
        h1 { font-size: 2em; font-weight: 700; margin: 1.2em 0 0.5em; line-height: 1.2; }
        h2 { font-size: 1.5em; font-weight: 600; margin: 1.1em 0 0.4em; line-height: 1.3; }
        h3 { font-size: 1.25em; font-weight: 600; margin: 1em 0 0.3em; }
        h4 { font-size: 1.1em; font-weight: 600; margin: 0.9em 0 0.25em; }
        h5, h6 { font-size: 1em; font-weight: 600; margin: 0.8em 0 0.2em; }
        p { margin: 0.8em 0; }
        a { color: #0066cc; text-decoration: none; }
        a:hover { text-decoration: underline; }
        code {
            font-family: 'SF Mono', Menlo, Consolas, monospace;
            font-size: 0.88em;
            background: rgba(128,128,128,0.1);
            padding: 2px 6px;
            border-radius: 4px;
        }
        pre {
            background: rgba(128,128,128,0.07);
            border-radius: 8px;
            padding: 16px 20px;
            overflow-x: auto;
            margin: 1em 0;
            line-height: 1.5;
        }
        pre code { background: none; padding: 0; font-size: 0.85em; }
        blockquote {
            border-left: 3px solid #0066cc;
            margin: 1em 0;
            padding: 0.25em 1em;
            color: #6e6e73;
        }
        blockquote p { margin: 0.4em 0; }
        table { border-collapse: collapse; width: 100%; margin: 1em 0; font-size: 0.95em; }
        th, td { border: 1px solid rgba(128,128,128,0.2); padding: 8px 12px; }
        th { background: rgba(128,128,128,0.05); font-weight: 600; }
        img { max-width: 100%; border-radius: 6px; margin: 0.5em 0; }
        hr { border: none; border-top: 1px solid rgba(128,128,128,0.2); margin: 2em 0; }
        ul, ol { padding-left: 1.5em; margin: 0.6em 0; }
        li { margin: 0.25em 0; }
        .task-list { list-style: none; padding-left: 0; }
        .task-item { display: flex; align-items: baseline; gap: 6px; margin: 0.3em 0; }
        .task-item input[type="checkbox"] { margin: 0; }
        .frontmatter {
            background: rgba(128,128,128,0.05);
            border-radius: 8px;
            padding: 4px 16px;
            margin-bottom: 24px;
            font-size: 0.9em;
        }
        .frontmatter summary {
            cursor: pointer;
            font-weight: 500;
            padding: 8px 0;
            user-select: none;
        }
        .frontmatter pre { margin: 0 0 8px; background: none; padding: 0 4px; }
        .fm-type {
            font-size: 0.75em;
            font-weight: 600;
            padding: 2px 8px;
            border-radius: 4px;
            background: rgba(128,128,128,0.12);
            vertical-align: middle;
        }
        del { opacity: 0.6; }
        </style>
        </head>
        <body>
        \(content)
        </body>
        </html>
        """
    }
}
