# Marquee Large-File Performance Plan

## Goals
- Keep line numbers visible for large files.
- Avoid repeated full-file scans while scrolling near the bottom of large files.
- Preserve the current working text rendering, caret behavior, and syntax highlighting behavior.

## Plan
1. Replace gutter prefix scans with a cached newline index.
   - Build newline offsets once when the editor view is created or receives a full programmatic text update.
   - Use binary search to map visible character positions to line numbers.
   - Incrementally update the index for edits instead of rescanning the whole file on every gutter draw.
2. Keep line numbers enabled in large-file mode.
   - Continue using large-file mode to restrain expensive features like full syntax highlighting.
   - Do not hide the gutter just because the document crosses the large-file threshold.
3. Keep syntax highlighting conservative for large files.
   - Avoid full-document highlighting in large-file mode.
   - Apply syntax highlighting only to the visible range plus context padding.
4. Reduce full text synchronization overhead.
   - Coalesce large-file `NSTextView.string` propagation into SwiftUI with a short debounce.
   - Flush pending syncs before app/window lifecycle transitions and keyboard save.
5. Improve large-file undo behavior.
   - Keep undo enabled for large files with a bounded undo stack.

## Execution Status
- [x] Plan captured.
- [x] Cached line-number lookup implemented.
- [x] Large-file line numbers re-enabled.
- [x] Large-file visible-range syntax highlighting enabled.
- [x] Large-file text synchronization coalesced.
- [x] Large-file undo changed from disabled to bounded.
- [x] Build verified.
