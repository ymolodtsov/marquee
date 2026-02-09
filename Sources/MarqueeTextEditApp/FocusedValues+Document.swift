import SwiftUI

struct DuplicateDocumentHandler {
    let action: () -> Void
}

struct SyntaxLanguageHandler {
    let currentLanguage: SyntaxLanguage
    let setLanguage: (SyntaxLanguage) -> Void
}

private struct DuplicateDocumentHandlerKey: FocusedValueKey {
    typealias Value = DuplicateDocumentHandler
}

private struct SyntaxLanguageHandlerKey: FocusedValueKey {
    typealias Value = SyntaxLanguageHandler
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
}
