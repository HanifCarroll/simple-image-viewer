import AppKit
import SwiftUI

final class ViewerWindow: NSWindow {
    weak var store: ImageStore?

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

final class ActiveViewerStore {
    static let shared = ActiveViewerStore()

    weak var store: ImageStore?

    private init() {}
}

struct ViewerWindowStoreBinder: NSViewRepresentable {
    let store: ImageStore

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            if view.window?.isKeyWindow == true {
                ActiveViewerStore.shared.store = store
            }
            (view.window as? ViewerWindow)?.store = store
            context.coordinator.bind(to: view.window, store: store)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observer: NSObjectProtocol?

        func bind(to window: NSWindow?, store: ImageStore) {
            guard self.window !== window else { return }
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            self.window = window
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { _ in
                ActiveViewerStore.shared.store = store
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
