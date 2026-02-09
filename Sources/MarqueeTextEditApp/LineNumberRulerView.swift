import AppKit

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let labelFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private let labelColor = NSColor.secondaryLabelColor
    private let backgroundColor = NSColor.textBackgroundColor
    private var observers: [NSObjectProtocol] = []

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)

        clientView = textView
        ruleThickness = 48

        scrollView.contentView.postsBoundsChangedNotifications = true
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.needsDisplay = true
        })

        observers.append(center.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            self?.needsDisplay = true
        })

        observers.append(center.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            self?.needsDisplay = true
        })
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        backgroundColor.setFill()
        rect.fill()

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        if visibleGlyphRange.length == 0 { return }
        let relativePoint = convert(NSPoint.zero, from: textView)

        let fullText = textView.string as NSString
        var glyphIndex = visibleGlyphRange.location

        while glyphIndex < NSMaxRange(visibleGlyphRange) {
            var lineGlyphRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            let prefixRange = NSRange(location: 0, length: charIndex)
            let lineNumber = 1 + countNewlines(in: fullText, range: prefixRange)

            let label = "\(lineNumber)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: labelColor
            ]

            let labelSize = label.size(withAttributes: attributes)
            let x = ruleThickness - labelSize.width - 8
            let y = lineRect.minY + relativePoint.y + (lineRect.height - labelSize.height) / 2
            label.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)

            glyphIndex = NSMaxRange(lineGlyphRange)
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
            let nextLocation = found.location + found.length
            if nextLocation >= NSMaxRange(range) { break }
            searchRange = NSRange(location: nextLocation, length: NSMaxRange(range) - nextLocation)
        }

        return count
    }
}
