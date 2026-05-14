import AppKit
import SwiftUI

struct KeyCommandView: NSViewRepresentable {
    let store: ImageStore

    func makeNSView(context: Context) -> KeyCommandNSView {
        KeyCommandNSView(store: store)
    }

    func updateNSView(_ view: KeyCommandNSView, context: Context) {
        view.store = store
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
    }
}

final class KeyCommandNSView: NSView {
    weak var store: ImageStore?

    init(store: ImageStore) {
        self.store = store
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 123:
            store?.navigate(-1)
        case 124:
            store?.navigate(1)
        default:
            super.keyDown(with: event)
        }
    }
}
