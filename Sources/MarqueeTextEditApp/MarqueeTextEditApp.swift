import SwiftUI
import AppKit

@main
struct MarqueeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @FocusedValue(\.duplicateDocumentHandler) private var duplicateHandler
    @FocusedValue(\.syntaxLanguageHandler) private var syntaxHandler
    @FocusedValue(\.previewHandler) private var previewHandler

    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { file in
            EditorView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    appDelegate.newDocumentTab()
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("Duplicate") {
                    duplicateHandler?.action()
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(duplicateHandler == nil)

                Divider()

                Button("Check for Updates...") {
                    appDelegate.openUpdatesPage()
                }
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

            CommandMenu("Search") {
                Button("Search...") {
                    performTextFinderAction(.showFindInterface)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button("Search & Replace...") {
                    performTextFinderAction(.showReplaceInterface)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])

                Divider()

                Button("Find Next") {
                    performTextFinderAction(.nextMatch)
                }
                .keyboardShortcut("g", modifiers: [.command])

                Button("Find Previous") {
                    performTextFinderAction(.previousMatch)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            CommandMenu("Syntax") {
                Button(previewHandler?.isShowingPreview == true ? "Hide Preview" : "Show Preview") {
                    previewHandler?.togglePreview()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(previewHandler?.isMarkdown != true)

                Divider()

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
        .windowToolbarStyle(.unified)
    }

    private func canSelectTab(at index: Int) -> Bool {
        guard let windows = NSApp.keyWindow?.tabGroup?.windows else { return false }
        return windows.indices.contains(index)
    }

    private func selectTab(at index: Int) {
        guard let windows = NSApp.keyWindow?.tabGroup?.windows, windows.indices.contains(index) else { return }
        windows[index].makeKeyAndOrderFront(nil)
    }

    private func performTextFinderAction(_ action: NSTextFinder.Action) {
        let sender = NSMenuItem()
        sender.tag = action.rawValue

        if let responder = NSApp.keyWindow?.firstResponder,
           responder.tryToPerform(#selector(NSResponder.performTextFinderAction(_:)), with: sender) {
            return
        }

        if NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: sender) {
            return
        }

        _ = performLegacyFindPanelAction(action)
    }

    private func performLegacyFindPanelAction(_ action: NSTextFinder.Action) -> Bool {
        let sender = NSMenuItem()
        switch action {
        case .showFindInterface:
            sender.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        case .showReplaceInterface:
            sender.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        case .nextMatch:
            sender.tag = Int(NSFindPanelAction.next.rawValue)
        case .previousMatch:
            sender.tag = Int(NSFindPanelAction.previous.rawValue)
        default:
            return false
        }

        return NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: sender)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowObserver: NSObjectProtocol?
    private var configuredWindowIDs = Set<ObjectIdentifier>()
    private let defaultDocumentWindowSize = NSSize(width: 960, height: 680)
    private let minimumDocumentWindowSize = NSSize(width: 560, height: 360)
    private let documentWindowAutosaveName = "MarqueeDocumentWindow"
    private let updatesURL = URL(string: "https://github.com/ymolodtsov/marquee/releases/latest")!

    func newDocumentTab() {
        guard let sourceWindow = NSApp.keyWindow ?? NSApp.mainWindow else {
            NSDocumentController.shared.newDocument(nil)
            return
        }

        do {
            let document = try NSDocumentController.shared.openUntitledDocumentAndDisplay(false)
            if document.windowControllers.isEmpty {
                document.makeWindowControllers()
            }

            guard let newWindow = document.windowControllers.compactMap(\.window).first else {
                document.showWindows()
                return
            }

            configure(newWindow)
            sourceWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
        } catch {
            NSDocumentController.shared.newDocument(nil)
        }
    }

    func openUpdatesPage() {
        NSWorkspace.shared.open(updatesURL)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            self.configure(window)
        }

        for window in NSApp.windows {
            configure(window)
        }
    }

    private func configure(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.tabbingMode = .preferred

        let windowID = ObjectIdentifier(window)
        guard !configuredWindowIDs.contains(windowID) else { return }
        configuredWindowIDs.insert(windowID)

        window.minSize = minimumDocumentWindowSize
        window.setFrameAutosaveName(documentWindowAutosaveName)

        if window.frame.width < minimumDocumentWindowSize.width ||
           window.frame.height < minimumDocumentWindowSize.height {
            window.setContentSize(defaultDocumentWindowSize)
            window.center()
        }
    }

}
