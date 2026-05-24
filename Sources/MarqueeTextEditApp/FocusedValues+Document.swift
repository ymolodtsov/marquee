import SwiftUI

struct DuplicateDocumentHandler {
    let action: () -> Void
}

struct SyntaxLanguageHandler {
    let currentLanguage: SyntaxLanguage
    let setLanguage: (SyntaxLanguage) -> Void
}

struct PreviewHandler {
    let isMarkdown: Bool
    let isShowingPreview: Bool
    let togglePreview: () -> Void
}

private struct DuplicateDocumentHandlerKey: FocusedValueKey {
    typealias Value = DuplicateDocumentHandler
}

private struct SyntaxLanguageHandlerKey: FocusedValueKey {
    typealias Value = SyntaxLanguageHandler
}

private struct PreviewHandlerKey: FocusedValueKey {
    typealias Value = PreviewHandler
}

extension FocusedValues {
    var duplicateDocumentHandler: DuplicateDocumentHandler? {
        get { self[DuplicateDocumentHandlerKey.self] }
        set { self[DuplicateDocumentHandlerKey.self] = newValue }
    }

    var syntaxLanguageHandler: SyntaxLanguageHandler? {
        get { self[SyntaxLanguageHandlerKey.self] }
        set { self[SyntaxLanguageHandlerKey.self] = newValue }
    }

    var previewHandler: PreviewHandler? {
        get { self[PreviewHandlerKey.self] }
        set { self[PreviewHandlerKey.self] = newValue }
    }
}
