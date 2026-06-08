import SwiftUI
import AppKit

struct SyntaxTextView: NSViewRepresentable {
    @Binding var text: String
    let language: SyntaxLanguage
    private static let largeFileThresholdBytes = 5_000_000
    private static let largeFileUndoLimit = 50

    private static func isLargeFile(_ text: String) -> Bool {
        text.lengthOfBytes(using: .utf8) >= largeFileThresholdBytes
    }

    private static func configureUndo(for textView: NSTextView, isLargeFileMode: Bool) {
        textView.allowsUndo = true
        textView.undoManager?.levelsOfUndo = isLargeFileMode ? largeFileUndoLimit : 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> EditorContainerView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor

        guard let textView = scrollView.documentView as? NSTextView else {
            return EditorContainerView(gutterView: NSView(frame: .zero), scrollView: scrollView)
        }

        textView.isRichText = false
        textView.usesFontPanel = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFindBar = true
        textView.layoutManager?.allowsNonContiguousLayout = true

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDataDetectionEnabled = false

        textView.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 0, height: 4)

        textView.string = text
        textView.delegate = context.coordinator

        let lineIndex = LineNumberIndex(text: textView.string)
        let gutterView = LineNumberGutterView(textView: textView, lineIndex: lineIndex)
        let container = EditorContainerView(gutterView: gutterView, scrollView: scrollView)
        let isLargeFileMode = Self.isLargeFile(text)
        container.setShowsLineNumbers(true)
        Self.configureUndo(for: textView, isLargeFileMode: isLargeFileMode)

        context.coordinator.textView = textView
        context.coordinator.gutterView = gutterView
        context.coordinator.lineIndex = lineIndex
        context.coordinator.lastSyncedText = text
        context.coordinator.lastLanguage = language
        context.coordinator.isLargeFileMode = isLargeFileMode
        context.coordinator.attachObservers(scrollView: scrollView)

        if !isLargeFileMode, let lm = textView.layoutManager {
            SyntaxHighlighter.shared.apply(to: lm, source: textView.string, language: language)
        }

        DispatchQueue.main.async {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            textView.window?.makeFirstResponder(textView)
            Self.configureUndo(for: textView, isLargeFileMode: isLargeFileMode)
            if isLargeFileMode {
                context.coordinator.scheduleHighlight()
            }
            gutterView.needsDisplay = true
        }

        return container
    }

    func updateNSView(_ nsView: EditorContainerView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        let isLargeFileMode = Self.isLargeFile(text)

        if context.coordinator.isLargeFileMode != isLargeFileMode {
            context.coordinator.isLargeFileMode = isLargeFileMode
            Self.configureUndo(for: textView, isLargeFileMode: isLargeFileMode)
            nsView.setShowsLineNumbers(true)
        }

        if context.coordinator.shouldApplyDocumentText(text) {
            context.coordinator.isProgrammaticUpdate = true
            textView.string = text
            context.coordinator.isProgrammaticUpdate = false
            context.coordinator.lastSyncedText = text
            context.coordinator.hasUnsyncedLocalChanges = false
            context.coordinator.lineIndex?.rebuild(text: textView.string)
            context.coordinator.highlightedRange = nil
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            if !isLargeFileMode, let lm = textView.layoutManager {
                SyntaxHighlighter.shared.apply(to: lm, source: textView.string, language: language)
            } else {
                context.coordinator.scheduleHighlight()
            }
            context.coordinator.gutterView?.needsDisplay = true
        } else if context.coordinator.lastLanguage != language {
            context.coordinator.highlightedRange = nil
            if let lm = textView.layoutManager {
                let visibleRange = context.coordinator.visibleCharacterRange()
                SyntaxHighlighter.shared.apply(to: lm, source: textView.string, language: language, in: visibleRange)
            }
        }

        context.coordinator.lastLanguage = language
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextView
        weak var textView: NSTextView?
        weak var gutterView: LineNumberGutterView?
        var lineIndex: LineNumberIndex?
        var isProgrammaticUpdate = false
        var isLargeFileMode = false
        var hasUnsyncedLocalChanges = false
        var lastSyncedText = ""
        var lastLanguage: SyntaxLanguage = .plainText
        private var pendingHighlight: DispatchWorkItem?
        private var pendingTextSync: DispatchWorkItem?
        private var textSyncGeneration = 0
        private var pendingLineIndexEdit: PendingLineIndexEdit?
        fileprivate var highlightedRange: NSRange?
        private var boundsObserver: NSObjectProtocol?
        private var textObserver: NSObjectProtocol?
        private var selectionObserver: NSObjectProtocol?
        private var documentSaveObserver: NSObjectProtocol?
        private var appResignObserver: NSObjectProtocol?
        private var windowWillCloseObserver: NSObjectProtocol?
        private var keyDownMonitor: Any?

        init(_ parent: SyntaxTextView) {
            self.parent = parent
        }

        deinit {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
            if let textObserver {
                NotificationCenter.default.removeObserver(textObserver)
            }
            if let selectionObserver {
                NotificationCenter.default.removeObserver(selectionObserver)
            }
            if let documentSaveObserver {
                NotificationCenter.default.removeObserver(documentSaveObserver)
            }
            if let appResignObserver {
                NotificationCenter.default.removeObserver(appResignObserver)
            }
            if let windowWillCloseObserver {
                NotificationCenter.default.removeObserver(windowWillCloseObserver)
            }
            if let keyDownMonitor {
                NSEvent.removeMonitor(keyDownMonitor)
            }
            pendingHighlight?.cancel()
            pendingTextSync?.cancel()
        }

        func attachObservers(scrollView: NSScrollView) {
            guard boundsObserver == nil, let textView else { return }

            scrollView.contentView.postsBoundsChangedNotifications = true

            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.gutterView?.needsDisplay = true
                self?.applyScrollHighlightIfNeeded()
            }

            textObserver = NotificationCenter.default.addObserver(
                forName: NSText.didChangeNotification,
                object: textView,
                queue: .main
            ) { [weak self] _ in
                self?.gutterView?.needsDisplay = true
            }

            selectionObserver = NotificationCenter.default.addObserver(
                forName: NSTextView.didChangeSelectionNotification,
                object: textView,
                queue: .main
            ) { [weak self] _ in
                self?.gutterView?.needsDisplay = true
            }

            documentSaveObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("NSDocumentWillSaveNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.flushPendingTextSync()
            }

            appResignObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.flushPendingTextSync()
            }

            windowWillCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self, let textView = self.textView else { return }
                if notification.object as? NSWindow === textView.window {
                    self.flushPendingTextSync()
                }
            }

            keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers?.lowercased() == "s" {
                    self?.flushPendingTextSync()
                }
                return event
            }
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if !isProgrammaticUpdate {
                pendingLineIndexEdit = PendingLineIndexEdit(
                    range: affectedCharRange,
                    replacement: replacementString
                )
            }
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate, let textView else { return }
            if let pendingLineIndexEdit, let replacement = pendingLineIndexEdit.replacement {
                lineIndex?.applyEdit(
                    range: pendingLineIndexEdit.range,
                    replacement: replacement
                )
                self.pendingLineIndexEdit = nil
            } else {
                lineIndex?.rebuild(text: textView.string)
                pendingLineIndexEdit = nil
            }
            syncDocumentText(from: textView)
            scheduleHighlight()
        }

        func shouldApplyDocumentText(_ text: String) -> Bool {
            guard let textView else { return false }
            if hasUnsyncedLocalChanges && text == lastSyncedText {
                return false
            }
            return textView.string != text
        }

        func flushPendingTextSync() {
            guard hasUnsyncedLocalChanges, let textView else { return }
            pendingTextSync?.cancel()
            pendingTextSync = nil
            textSyncGeneration += 1
            let latestText = textView.string
            parent.text = latestText
            lastSyncedText = latestText
            hasUnsyncedLocalChanges = false
        }

        private func syncDocumentText(from textView: NSTextView) {
            if isLargeFileMode {
                hasUnsyncedLocalChanges = true
                pendingTextSync?.cancel()
                textSyncGeneration += 1
                let generation = textSyncGeneration
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    guard generation == self.textSyncGeneration else { return }
                    self.flushPendingTextSync()
                }
                pendingTextSync = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
            } else {
                pendingTextSync?.cancel()
                pendingTextSync = nil
                textSyncGeneration += 1
                let latestText = textView.string
                parent.text = latestText
                lastSyncedText = latestText
                hasUnsyncedLocalChanges = false
            }
        }

        func scheduleHighlight() {
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let textView = self.textView, let lm = textView.layoutManager else { return }
                let source = textView.string
                let visibleRange = self.visibleCharacterRange()
                self.highlightedRange = nil
                SyntaxHighlighter.shared.apply(to: lm, source: source, language: self.parent.language, in: visibleRange)
                if let visibleRange {
                    self.highlightedRange = SyntaxHighlighter.shared.effectiveRange(for: visibleRange, totalLength: (source as NSString).length)
                }
                self.gutterView?.needsDisplay = true
            }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
        }

        private func applyScrollHighlightIfNeeded() {
            guard let textView, let lm = textView.layoutManager else { return }
            let source = textView.string
            let totalLength = (source as NSString).length
            guard let visibleRange = visibleCharacterRange() else { return }

            let needed = SyntaxHighlighter.shared.effectiveRange(for: visibleRange, totalLength: totalLength)

            if let prev = highlightedRange,
               prev.location <= needed.location,
               NSMaxRange(prev) >= NSMaxRange(needed) {
                return
            }

            SyntaxHighlighter.shared.apply(to: lm, source: source, language: parent.language, in: visibleRange)

            if let prev = highlightedRange {
                let unionStart = min(prev.location, needed.location)
                let unionEnd = max(NSMaxRange(prev), NSMaxRange(needed))
                highlightedRange = NSRange(location: unionStart, length: unionEnd - unionStart)
            } else {
                highlightedRange = needed
            }
        }

        func visibleCharacterRange() -> NSRange? {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return nil }
            let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
            return layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        }

        private struct PendingLineIndexEdit {
            let range: NSRange
            let replacement: String?
        }
    }
}

final class EditorContainerView: NSView {
    private let gutterWidth: CGFloat = 48
    let gutterView: NSView
    let scrollView: NSScrollView
    private var showsLineNumbers = true

    init(gutterView: NSView, scrollView: NSScrollView) {
        self.gutterView = gutterView
        self.scrollView = scrollView
        super.init(frame: .zero)

        addSubview(gutterView)
        addSubview(scrollView)

        gutterView.autoresizingMask = [.height]
        scrollView.autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let currentGutterWidth = showsLineNumbers ? gutterWidth : 0
        gutterView.frame = NSRect(x: 0, y: 0, width: currentGutterWidth, height: bounds.height)
        scrollView.frame = NSRect(x: currentGutterWidth, y: 0, width: max(bounds.width - currentGutterWidth, 0), height: bounds.height)
    }

    func setShowsLineNumbers(_ shows: Bool) {
        showsLineNumbers = shows
        gutterView.isHidden = !shows
        needsLayout = true
    }
}

final class LineNumberGutterView: NSView {
    weak var textView: NSTextView?
    private let lineIndex: LineNumberIndex
    private let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private let textColor = NSColor.secondaryLabelColor
    private let backgroundColor = NSColor.textBackgroundColor

    override var isFlipped: Bool { true }

    init(textView: NSTextView, lineIndex: LineNumberIndex) {
        self.textView = textView
        self.lineIndex = lineIndex
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        dirtyRect.fill()

        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        if visibleGlyphRange.length == 0 {
            let label = "1" as NSString
            let labelSize = label.size(withAttributes: attributes)
            label.draw(
                at: NSPoint(x: bounds.width - labelSize.width - 8, y: textView.textContainerInset.height),
                withAttributes: attributes
            )
            return
        }

        let fullText = textView.string as NSString
        var glyphIndex = visibleGlyphRange.location
        var drawnLineStarts: Set<Int> = []

        while glyphIndex < NSMaxRange(visibleGlyphRange) {
            var lineGlyphRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            let lineStart = fullText.lineRange(for: NSRange(location: charRange.location, length: 0)).location

            if drawnLineStarts.contains(lineStart) {
                glyphIndex = NSMaxRange(lineGlyphRange)
                continue
            }
            drawnLineStarts.insert(lineStart)

            let lineNumber = lineIndex.lineNumber(at: lineStart)

            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: attributes)
            let x = bounds.width - labelSize.width - 8

            let y = lineRect.minY + textView.textContainerOrigin.y - textView.visibleRect.minY + (lineRect.height - labelSize.height) / 2

            label.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
            glyphIndex = NSMaxRange(lineGlyphRange)
        }

        // Draw number for trailing empty line when text ends with a newline.
        if textView.string.hasSuffix("\n") {
            let lastLineStart = fullText.length
            if !drawnLineStarts.contains(lastLineStart) {
                let extraRect = layoutManager.extraLineFragmentRect
                if !extraRect.equalTo(.zero) {
                    let y = extraRect.minY + textView.textContainerOrigin.y - textView.visibleRect.minY
                    if y < bounds.maxY && y + extraRect.height > 0 {
                        let lineNumber = lineIndex.lineNumber(at: lastLineStart)
                        let label = "\(lineNumber)" as NSString
                        let labelSize = label.size(withAttributes: attributes)
                        let x = bounds.width - labelSize.width - 8
                        let drawY = y + (extraRect.height - labelSize.height) / 2
                        label.draw(at: NSPoint(x: x, y: drawY), withAttributes: attributes)
                    }
                }
            }
        }
    }
}

final class LineNumberIndex {
    private var newlineLocations: [Int] = []

    init(text: String) {
        rebuild(text: text)
    }

    func rebuild(text: String) {
        let nsText = text as NSString
        newlineLocations.removeAll(keepingCapacity: true)

        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.length > 0 {
            let found = nsText.range(of: "\n", options: [], range: searchRange)
            if found.location == NSNotFound {
                break
            }

            newlineLocations.append(found.location)

            let next = found.location + found.length
            searchRange = NSRange(location: next, length: nsText.length - next)
        }
    }

    func applyEdit(range: NSRange, replacement: String) {
        let replacementNewlineLocations = Self.newlineLocations(in: replacement, offsetBy: range.location)
        let removedRangeEnd = NSMaxRange(range)
        let lengthDelta = (replacement as NSString).length - range.length
        let firstRemovedIndex = lowerBound(for: range.location)
        let firstPreservedIndex = lowerBound(for: removedRangeEnd)

        var updated: [Int] = []
        updated.reserveCapacity(newlineLocations.count - (firstPreservedIndex - firstRemovedIndex) + replacementNewlineLocations.count)
        updated.append(contentsOf: newlineLocations[..<firstRemovedIndex])
        updated.append(contentsOf: replacementNewlineLocations)

        for location in newlineLocations[firstPreservedIndex...] {
            updated.append(location + lengthDelta)
        }

        newlineLocations = updated
    }

    func lineNumber(at characterLocation: Int) -> Int {
        lowerBound(for: characterLocation) + 1
    }

    private static func newlineLocations(in text: String, offsetBy offset: Int) -> [Int] {
        let nsText = text as NSString
        var locations: [Int] = []
        var searchRange = NSRange(location: 0, length: nsText.length)

        while searchRange.length > 0 {
            let found = nsText.range(of: "\n", options: [], range: searchRange)
            if found.location == NSNotFound {
                break
            }

            locations.append(offset + found.location)

            let next = found.location + found.length
            searchRange = NSRange(location: next, length: nsText.length - next)
        }

        return locations
    }

    private func lowerBound(for value: Int) -> Int {
        var low = 0
        var high = newlineLocations.count

        while low < high {
            let mid = (low + high) / 2
            if newlineLocations[mid] < value {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return low
    }
}
