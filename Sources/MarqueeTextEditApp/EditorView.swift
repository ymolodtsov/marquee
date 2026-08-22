import SwiftUI

struct EditorView: View {
    @Binding var document: TextDocument
    let fileURL: URL?

    @State private var selectedLanguage: SyntaxLanguage
    @State private var showingPreview = false
    @State private var previewSearchVisible = false
    @State private var previewSearchQuery = ""
    @State private var previewSearchRequestID = 0
    @State private var previewSearchBackwards = false
    @State private var previewSearchMatchFound: Bool?
    @FocusState private var previewSearchFieldFocused: Bool

    init(document: Binding<TextDocument>, fileURL: URL?) {
        self._document = document
        self.fileURL = fileURL
        self._selectedLanguage = State(initialValue: SyntaxLanguage.from(fileURL: fileURL))
    }

    var body: some View {
        Group {
            if showingPreview && selectedLanguage == .markdown {
                VStack(spacing: 0) {
                    if previewSearchVisible {
                        previewSearchBar
                        Divider()
                    }

                    MarkdownPreviewView(
                        text: document.text,
                        searchQuery: previewSearchQuery,
                        searchRequestID: previewSearchRequestID,
                        searchBackwards: previewSearchBackwards,
                        onFindResult: { previewSearchMatchFound = $0 }
                    )
                }
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
                closePreviewSearch()
            }
        }
        .onChange(of: showingPreview) {
            if !showingPreview {
                closePreviewSearch()
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
        .focusedSceneValue(\.previewHandler, PreviewHandler(
            isMarkdown: selectedLanguage == .markdown,
            isShowingPreview: showingPreview,
            togglePreview: { showingPreview.toggle() },
            showSearch: showPreviewSearch,
            findNext: { findInPreview(backwards: false) },
            findPrevious: { findInPreview(backwards: true) }
        ))
    }

    private var previewSearchBar: some View {
        HStack(spacing: 8) {
            TextField("Search", text: Binding(
                get: { previewSearchQuery },
                set: { query in
                    previewSearchQuery = query
                    previewSearchBackwards = false
                    previewSearchMatchFound = nil
                }
            ))
                .textFieldStyle(.roundedBorder)
                .focused($previewSearchFieldFocused)
                .onSubmit {
                    findInPreview(backwards: false)
                }
                .frame(minWidth: 180, idealWidth: 260, maxWidth: 360)

            if previewSearchMatchFound == false && !previewSearchQuery.isEmpty {
                Text("No matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                findInPreview(backwards: true)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .help("Find Previous")
            .disabled(previewSearchQuery.isEmpty)

            Button {
                findInPreview(backwards: false)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .help("Find Next")
            .disabled(previewSearchQuery.isEmpty)

            Button {
                closePreviewSearch()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close Search")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(.bar)
        .onExitCommand {
            closePreviewSearch()
        }
    }

    private func showPreviewSearch() {
        previewSearchVisible = true
        DispatchQueue.main.async {
            previewSearchFieldFocused = true
        }
    }

    private func findInPreview(backwards: Bool) {
        guard !previewSearchQuery.isEmpty else {
            showPreviewSearch()
            return
        }

        previewSearchBackwards = backwards
        previewSearchRequestID += 1
    }

    private func closePreviewSearch() {
        previewSearchVisible = false
        previewSearchQuery = ""
        previewSearchMatchFound = nil
    }
}
