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

    private final class StoreBox {
        weak var store: ImageStore?

        init(_ store: ImageStore) {
            self.store = store
        }
    }

    private var stores: [ObjectIdentifier: StoreBox] = [:]
    weak var store: ImageStore?

    private init() {}

    func register(_ store: ImageStore, for window: NSWindow?) {
        guard let window else { return }
        stores[ObjectIdentifier(window)] = StoreBox(store)
        (window as? ViewerWindow)?.store = store
        if window.isKeyWindow || self.store == nil {
            self.store = store
        }
    }

    func activate(_ store: ImageStore) {
        self.store = store
    }

    func store(for window: NSWindow?) -> ImageStore? {
        if let window,
           let store = stores[ObjectIdentifier(window)]?.store {
            self.store = store
            return store
        }
        return store
    }

    func unregister(window: NSWindow) {
        stores.removeValue(forKey: ObjectIdentifier(window))
        if store == nil {
            store = nil
        }
    }
}

struct ViewerWindowStoreBinder: NSViewRepresentable {
    let store: ImageStore

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            ActiveViewerStore.shared.register(store, for: view.window)
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
                ActiveViewerStore.shared.activate(store)
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
