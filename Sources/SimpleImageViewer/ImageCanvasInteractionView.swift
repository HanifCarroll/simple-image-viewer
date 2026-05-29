import AppKit
import SwiftUI

struct ImageCanvasInteractionView: NSViewRepresentable {
    let onMagnify: (Double) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void
    let onCopy: () -> Void
    let canCopy: () -> Bool

    func makeNSView(context: Context) -> CanvasInteractionNSView {
        let view = CanvasInteractionNSView()
        view.onMagnify = onMagnify
        view.onScroll = onScroll
        view.onCopy = onCopy
        view.canCopy = canCopy
        return view
    }

    func updateNSView(_ view: CanvasInteractionNSView, context: Context) {
        view.onMagnify = onMagnify
        view.onScroll = onScroll
        view.onCopy = onCopy
        view.canCopy = canCopy
    }
}

final class CanvasInteractionNSView: NSView {
    var onMagnify: ((Double) -> Void)?
    var onScroll: ((CGFloat, CGFloat) -> Void)?
    var onCopy: (() -> Void)?
    var canCopy: (() -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func magnify(with event: NSEvent) {
        onMagnify?(Double(event.magnification))
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menu(for: event) else {
            super.rightMouseDown(with: event)
            return
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard canCopy?() == true else { return nil }
        let menu = NSMenu()
        let item = NSMenuItem(title: "Copy Image", action: #selector(copyImage), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func copyImage() {
        onCopy?()
    }
}
