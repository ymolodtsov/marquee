import SwiftUI
import UniformTypeIdentifiers

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] = {
        var types: Set<UTType> = [.plainText, .utf8PlainText, .sourceCode]

        let knownIdentifiers = [
            "public.css",
            "public.html",
            "public.xml",
            "public.json",
            "net.daringfireball.markdown",
            "com.netscape.javascript-source",
            "public.php-script",
            "public.python-script",
            "public.ruby-script"
        ]

        for identifier in knownIdentifiers {
            if let type = UTType(identifier) {
                types.insert(type)
            }
        }

        let extensions = ["md", "js", "ts", "php", "py", "rb", "html", "css", "xml", "toml", "json", "txt"]
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
