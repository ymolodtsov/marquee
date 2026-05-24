import SwiftUI

struct EditorView: View {
    @Binding var document: TextDocument
    let fileURL: URL?

    @State private var selectedLanguage: SyntaxLanguage
    @State private var showingPreview = false

    init(document: Binding<TextDocument>, fileURL: URL?) {
        self._document = document
        self.fileURL = fileURL
        self._selectedLanguage = State(initialValue: SyntaxLanguage.from(fileURL: fileURL))
    }

    var body: some View {
        Group {
            if showingPreview && selectedLanguage == .markdown {
                MarkdownPreviewView(text: document.text)
            } else {
                SyntaxTextView(text: $document.text, language: selectedLanguage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            if selectedLanguage == .markdown {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingPreview.toggle()
                    } label: {
                        Image(systemName: showingPreview ? "eye.fill" : "eye")
                    }
                    .help(showingPreview ? "Hide Preview" : "Show Preview")
                }
            }
            ToolbarItem(placement: .automatic) {
                Picker("Syntax", selection: $selectedLanguage) {
                    ForEach(SyntaxLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
            }
        }
        .onChange(of: selectedLanguage) {
            if selectedLanguage != .markdown {
                showingPreview = false
            }
        }
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
        .focusedValue(\.previewHandler, PreviewHandler(
            isMarkdown: selectedLanguage == .markdown,
            isShowingPreview: showingPreview,
            togglePreview: { showingPreview.toggle() }
        ))
    }
}
