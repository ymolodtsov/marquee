import SwiftUI
import AppKit

@main
struct MarqueeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @FocusedValue(\.duplicateDocumentHandler) private var duplicateHandler
    @FocusedValue(\.syntaxLanguageHandler) private var syntaxHandler

    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { file in
            EditorView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    NSDocumentController.shared.newDocument(nil)
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("Duplicate") {
                    duplicateHandler?.action()
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(duplicateHandler == nil)
            }

            CommandGroup(after: .windowArrangement) {
                Button("Previous Tab") {
                    NSApp.keyWindow?.selectPreviousTab(nil)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(NSApp.keyWindow?.tabGroup == nil)

                Button("Next Tab") {
                    NSApp.keyWindow?.selectNextTab(nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(NSApp.keyWindow?.tabGroup == nil)

                Divider()

                Button("Select Tab 1") {
                    selectTab(at: 0)
                }
                .keyboardShortcut("1", modifiers: [.command])
                .disabled(!canSelectTab(at: 0))

                Button("Select Tab 2") {
                    selectTab(at: 1)
                }
                .keyboardShortcut("2", modifiers: [.command])
                .disabled(!canSelectTab(at: 1))
            }

            CommandMenu("Syntax") {
                ForEach(SyntaxLanguage.allCases) { language in
                    Toggle(language.displayName, isOn: Binding(
                        get: { syntaxHandler?.currentLanguage == language },
                        set: { isOn in
                            if isOn {
                                syntaxHandler?.setLanguage(language)
                            }
                        }
                    ))
                    .disabled(syntaxHandler == nil)
                }
            }
        }
    }

    private func canSelectTab(at index: Int) -> Bool {
        guard let windows = NSApp.keyWindow?.tabGroup?.windows else { return false }
        return windows.indices.contains(index)
    }

    private func selectTab(at index: Int) {
        guard let windows = NSApp.keyWindow?.tabGroup?.windows, windows.indices.contains(index) else { return }
        windows[index].makeKeyAndOrderFront(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
    }
}
