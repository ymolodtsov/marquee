import SwiftUI

struct EditorView: View {
    @Binding var document: TextDocument
    let fileURL: URL?

    @State private var selectedLanguage: SyntaxLanguage

    init(document: Binding<TextDocument>, fileURL: URL?) {
        self._document = document
        self.fileURL = fileURL
        self._selectedLanguage = State(initialValue: SyntaxLanguage.from(fileURL: fileURL))
    }

    var body: some View {
        VStack(spacing: 0) {
            SyntaxTextView(text: $document.text, language: selectedLanguage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Text(selectedLanguage.displayName)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(Color(NSColor.textBackgroundColor))
        .focusedValue(\.duplicateDocumentHandler, DuplicateDocumentHandler {
            Task {
                await DuplicateDocumentAction.duplicate(text: document.text, fileURL: fileURL)
            }
        })
        .focusedValue(\.syntaxLanguageHandler, SyntaxLanguageHandler(
            currentLanguage: selectedLanguage,
            setLanguage: { language in
                selectedLanguage = language
            }
        ))
    }
}
