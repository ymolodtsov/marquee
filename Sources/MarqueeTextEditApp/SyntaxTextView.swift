import SwiftUI
import AppKit

struct SyntaxTextView: NSViewRepresentable {
    @Binding var text: String
    let language: SyntaxLanguage
    private static let largeFileThresholdBytes = 5_000_000

    private static func isLargeFile(_ text: String) -> Bool {
        text.lengthOfBytes(using: .utf8) >= largeFileThresholdBytes
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

        let gutterView = LineNumberGutterView(textView: textView)
        let container = EditorContainerView(gutterView: gutterView, scrollView: scrollView)
        let isLargeFileMode = Self.isLargeFile(text)
        container.setShowsLineNumbers(!isLargeFileMode)
        textView.allowsUndo = !isLargeFileMode

        context.coordinator.textView = textView
        context.coordinator.gutterView = gutterView
        context.coordinator.lastLanguage = language
        context.coordinator.isLargeFileMode = isLargeFileMode
        context.coordinator.attachObservers(scrollView: scrollView)

        if !isLargeFileMode, let storage = textView.textStorage {
            SyntaxHighlighter.shared.apply(to: storage, language: language)
        }

        DispatchQueue.main.async {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            textView.window?.makeFirstResponder(textView)
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
            textView.allowsUndo = !isLargeFileMode
            nsView.setShowsLineNumbers(!isLargeFileMode)
        }

        if textView.string != text {
            context.coordinator.isProgrammaticUpdate = true
            textView.string = text
            context.coordinator.isProgrammaticUpdate = false
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            if !isLargeFileMode, let storage = textView.textStorage {
                SyntaxHighlighter.shared.apply(to: storage, language: language)
            }
            context.coordinator.gutterView?.needsDisplay = true
        } else if context.coordinator.lastLanguage != language {
            if !isLargeFileMode, let storage = textView.textStorage {
                SyntaxHighlighter.shared.apply(to: storage, language: language)
            }
        }

        context.coordinator.lastLanguage = language
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextView
        weak var textView: NSTextView?
        weak var gutterView: LineNumberGutterView?
        var isProgrammaticUpdate = false
        var isLargeFileMode = false
        var lastLanguage: SyntaxLanguage = .plainText
        private var pendingHighlight: DispatchWorkItem?
        private var boundsObserver: NSObjectProtocol?
        private var textObserver: NSObjectProtocol?
        private var selectionObserver: NSObjectProtocol?

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
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate, let textView else { return }
            parent.text = textView.string
            scheduleHighlight()
        }

        private func scheduleHighlight() {
            guard !isLargeFileMode else { return }
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let textView = self.textView, let storage = textView.textStorage else { return }
                guard SyntaxHighlighter.shared.shouldHighlight(textLength: storage.length) else { return }
                let selection = textView.selectedRange()
                SyntaxHighlighter.shared.apply(to: storage, language: self.parent.language)
                textView.setSelectedRange(selection)
                self.gutterView?.needsDisplay = true
            }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
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
    private let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private let textColor = NSColor.secondaryLabelColor
    private let backgroundColor = NSColor.textBackgroundColor

    override var isFlipped: Bool { true }

    init(textView: NSTextView) {
        self.textView = textView
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

            let prefixRange = NSRange(location: 0, length: lineStart)
            let lineNumber = 1 + countNewlines(in: fullText, range: prefixRange)

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
                        let lineNumber = 1 + countNewlines(in: fullText, range: NSRange(location: 0, length: lastLineStart))
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

    private func countNewlines(in text: NSString, range: NSRange) -> Int {
        guard range.length > 0 else { return 0 }

        var count = 0
        var searchRange = range

        while true {
            let found = text.range(of: "\n", options: [], range: searchRange)
            if found.location == NSNotFound { break }

            count += 1
            let next = found.location + found.length
            if next >= NSMaxRange(range) { break }
            searchRange = NSRange(location: next, length: NSMaxRange(range) - next)
        }

        return count
    }
}
