import AppKit
import SwiftUI

struct ImageCanvasInteractionView: NSViewRepresentable {
    let onMagnify: (Double) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void
    let onCopy: () -> Void
    let onRotateLeft: () -> Void
    let onRotateRight: () -> Void
    let canCopy: () -> Bool
    let canRotate: () -> Bool

    func makeNSView(context: Context) -> CanvasInteractionNSView {
        let view = CanvasInteractionNSView()
        view.onMagnify = onMagnify
        view.onScroll = onScroll
        view.onCopy = onCopy
        view.onRotateLeft = onRotateLeft
        view.onRotateRight = onRotateRight
        view.canCopy = canCopy
        view.canRotate = canRotate
        return view
    }

    func updateNSView(_ view: CanvasInteractionNSView, context: Context) {
        view.onMagnify = onMagnify
        view.onScroll = onScroll
        view.onCopy = onCopy
        view.onRotateLeft = onRotateLeft
        view.onRotateRight = onRotateRight
        view.canCopy = canCopy
        view.canRotate = canRotate
    }
}

final class CanvasInteractionNSView: NSView {
    var onMagnify: ((Double) -> Void)?
    var onScroll: ((CGFloat, CGFloat) -> Void)?
    var onCopy: (() -> Void)?
    var onRotateLeft: (() -> Void)?
    var onRotateRight: (() -> Void)?
    var canCopy: (() -> Bool)?
    var canRotate: (() -> Bool)?

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
        let isCopyEnabled = canCopy?() == true
        let isRotateEnabled = canRotate?() == true
        guard isCopyEnabled || isRotateEnabled else { return nil }

        let menu = NSMenu()
        if isRotateEnabled {
            let rotateLeft = NSMenuItem(title: "Rotate Left", action: #selector(rotateLeft), keyEquivalent: "")
            rotateLeft.target = self
            menu.addItem(rotateLeft)

            let rotateRight = NSMenuItem(title: "Rotate Right", action: #selector(rotateRight), keyEquivalent: "")
            rotateRight.target = self
            menu.addItem(rotateRight)
        }

        if isCopyEnabled {
            if isRotateEnabled {
                menu.addItem(.separator())
            }
            let item = NSMenuItem(title: "Copy Image", action: #selector(copyImage), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    @objc private func copyImage() {
        onCopy?()
    }

    @objc private func rotateLeft() {
        onRotateLeft?()
    }

    @objc private func rotateRight() {
        onRotateRight?()
    }
}
