import SwiftUI
import UniformTypeIdentifiers

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] = {
        var types: Set<UTType> = [.plainText, .utf8PlainText, .sourceCode, .data]

        let knownIdentifiers = [
            "public.css",
            "public.html",
            "public.xml",
            "public.json",
            "public.sql",
            "public.script",
            "public.shell-script",
            "public.c-source",
            "public.c-header",
            "public.c-plus-plus-source",
            "public.c-plus-plus-header",
            "public.objective-c-source",
            "public.objective-c-plus-plus-source",
            "public.swift-source",
            "com.apple.property-list",
            "com.sun.java-source",
            "net.daringfireball.markdown",
            "com.netscape.javascript-source",
            "public.php-script",
            "public.python-script",
            "public.ruby-script",
            "public.perl-script",
            "public.yaml",
            "public.svg-image",
            "public.comma-separated-values-text"
        ]

        for identifier in knownIdentifiers {
            if let type = UTType(identifier) {
                types.insert(type)
            }
        }

        let extensions = [
            "txt", "md", "mdx",
            "js", "jsx", "ts", "tsx", "mjs", "cjs",
            "html", "htm", "css", "scss", "sass", "less",
            "json", "jsonc", "xml", "yaml", "yml", "toml",
            "svg", "csv", "tsv", "log",
            "env", "gitignore", "gitattributes", "editorconfig",
            "swift", "go", "rs", "java", "kt", "kts", "scala",
            "c", "h", "cpp", "cc", "cxx", "hpp", "hxx", "m", "mm",
            "cs", "fs",
            "py", "rb", "php", "pl", "pm", "lua", "r",
            "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd",
            "sql",
            "ex", "exs", "erl", "hrl", "hs", "lhs",
            "ml", "mli", "clj", "cljs",
            "dart", "vue", "svelte", "astro",
            "graphql", "gql", "proto",
            "tf", "hcl", "dockerfile", "dockerignore",
            "makefile", "cmake", "gradle",
            "properties", "ini", "cfg", "conf", "config",
            "lock", "diff", "patch",
            "rst", "tex", "bib",
            "zig", "nim", "v", "d", "sol", "prisma",
        ]
        for ext in extensions {
            if let type = UTType(filenameExtension: ext, conformingTo: .sourceCode) ??
                UTType(filenameExtension: ext, conformingTo: .plainText) ??
                UTType(filenameExtension: ext) {
                types.insert(type)
            }
        }

        return types.sorted { $0.identifier < $1.identifier }
    }()

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
