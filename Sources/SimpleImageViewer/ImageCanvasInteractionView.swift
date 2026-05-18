import AppKit
import SwiftUI

struct ImageCanvasInteractionView: NSViewRepresentable {
    let onMagnify: (Double) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> CanvasInteractionNSView {
        let view = CanvasInteractionNSView()
        view.onMagnify = onMagnify
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: CanvasInteractionNSView, context: Context) {
        view.onMagnify = onMagnify
        view.onScroll = onScroll
    }
}

final class CanvasInteractionNSView: NSView {
    var onMagnify: ((Double) -> Void)?
    var onScroll: ((CGFloat, CGFloat) -> Void)?

    override var acceptsFirstResponder: Bool { false }

    override func magnify(with event: NSEvent) {
        onMagnify?(Double(event.magnification))
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
    }
}
