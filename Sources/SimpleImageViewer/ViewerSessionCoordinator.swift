import AppKit
import Combine
import SwiftUI

final class ViewerSessionCoordinator {
    private final class Session {
        let store: ImageStore
        weak var window: NSWindow?
        var controller: NSWindowController?
        var titleCancellable: AnyCancellable?
        var keyObserver: NSObjectProtocol?
        var moveObserver: NSObjectProtocol?
        var resizeObserver: NSObjectProtocol?
        var closeObserver: NSObjectProtocol?

        init(store: ImageStore, window: NSWindow) {
            self.store = store
            self.window = window
        }
    }

    private var sessions: [ObjectIdentifier: Session] = [:]
    private var sessionOrder: [ObjectIdentifier] = []
    private var activeSessionID: ObjectIdentifier?
    private weak var initialStore: ImageStore?
    private var pendingURLs: [URL] = []
    private var recentlyOpenedURLKeys: Set<String> = []
    private var usedInitialWindowForExternalOpen = false

    func queueLaunchURLs(_ urls: [URL]) {
        pendingURLs.append(contentsOf: urls)
    }

    func register(_ store: ImageStore, for window: NSWindow?) {
        guard let window else { return }

        let id = ObjectIdentifier(window)
        if let session = sessions[id], session.store === store {
            updateWindowTitle(window, store: store)
            return
        }

        unregister(window)

        let session = Session(store: store, window: window)
        sessions[id] = session
        sessionOrder.append(id)
        (window as? ViewerWindow)?.sessionCoordinator = self

        if window.isKeyWindow || activeSessionID == nil {
            activeSessionID = id
        }

        updateWindowTitle(window, store: store)
        session.titleCancellable = store.$status.sink { [weak self, weak window, weak store] _ in
            DispatchQueue.main.async {
                guard let self, let window, let store else { return }
                self.updateWindowTitle(window, store: store)
            }
        }
        session.keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let window else { return }
            self?.activate(window)
        }
        session.moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            guard let window else { return }
            WindowFrameStore.save(window.frame)
        }
        session.resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            guard let window else { return }
            WindowFrameStore.save(window.frame)
        }
        session.closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let window else { return }
            WindowFrameStore.save(window.frame)
            self?.unregister(window)
        }
    }

    func openNewViewerWindow() {
        openWindow(store: ImageStore())
    }

    func openInitialWindow() {
        guard sessions.isEmpty else { return }

        let store = ImageStore()
        initialStore = store
        openWindow(store: store)
        openPendingURLs()
    }

    func closeUnmanagedWindows() {
        for window in NSApp.windows where sessions[ObjectIdentifier(window)] == nil {
            window.close()
        }
    }

    func openPanelInNewWindow() {
        let store = ImageStore()
        openWindow(store: store)
        store.openPanel()
    }

    func openActiveWindowPanel() {
        if let session = activeSession() {
            session.store.openPanel()
        } else {
            openPanelInNewWindow()
        }
    }

    func open(_ urls: [URL]) {
        guard initialStore != nil else {
            pendingURLs.append(contentsOf: urls)
            return
        }

        var urlsToOpen = urls.filter { shouldOpenURL($0) }
        if let initialSession = reusableInitialSession(), let firstURL = urlsToOpen.first {
            usedInitialWindowForExternalOpen = true
            initialSession.store.open(firstURL)
            urlsToOpen.removeFirst()
        }

        for url in urlsToOpen {
            let store = ImageStore()
            openWindow(store: store)
            store.open(url)
        }
    }

    func navigateActiveWindow(_ delta: Int) {
        activeSession()?.store.navigate(delta)
    }

    func zoomActiveWindowIn() {
        activeSession()?.store.zoomIn()
    }

    func zoomActiveWindowOut() {
        activeSession()?.store.zoomOut()
    }

    func toggleActiveWindowPlayback() {
        activeSession()?.store.togglePlayback()
    }

    @discardableResult
    func navigate(_ delta: Int, in window: NSWindow?) -> Bool {
        guard let session = session(for: window) else { return false }
        session.store.navigate(delta)
        return true
    }

    func selectFirstInActiveWindow() {
        activeSession()?.store.select(0)
    }

    func selectLastInActiveWindow() {
        guard let store = activeSession()?.store else { return }
        store.select(store.images.count - 1)
    }

    private func openPendingURLs() {
        guard !pendingURLs.isEmpty else { return }
        let urls = pendingURLs
        pendingURLs.removeAll()
        open(urls)
    }

    @discardableResult
    private func openWindow(store: ImageStore) -> NSWindowController {
        let initialFrame = WindowFrameStore.initialFrame
        let contentView = ContentView(store: store)
            .frame(minWidth: 760, idealWidth: 1100, minHeight: 520, idealHeight: 760)

        let window = ViewerWindow(
            contentRect: initialFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Simple Image Viewer"
        window.contentViewController = NSHostingController(rootView: contentView)

        let controller = NSWindowController(window: window)
        register(store, for: window)
        sessions[ObjectIdentifier(window)]?.controller = controller
        controller.showWindow(nil)
        window.setFrame(initialFrame, display: true)
        NSApp.activate(ignoringOtherApps: true)
        return controller
    }

    private func reusableInitialSession() -> Session? {
        guard !usedInitialWindowForExternalOpen,
              let initialStore,
              !initialStore.hasOpenedContent
        else {
            return nil
        }
        return sessions.values.first { $0.store === initialStore }
    }

    private func shouldOpenURL(_ url: URL) -> Bool {
        let key = urlKey(url)
        guard !recentlyOpenedURLKeys.contains(key) else { return false }
        recentlyOpenedURLKeys.insert(key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.recentlyOpenedURLKeys.remove(key)
        }
        return true
    }

    private func activeSession() -> Session? {
        for window in [NSApp.keyWindow, NSApp.mainWindow] {
            if let session = session(for: window) {
                return session
            }
        }

        if let activeSessionID, let session = sessions[activeSessionID] {
            return session
        }

        return sessionOrder.reversed().compactMap { sessions[$0] }.first
    }

    private func session(for window: NSWindow?) -> Session? {
        guard let window else { return nil }
        let id = ObjectIdentifier(window)
        guard let session = sessions[id] else { return nil }
        activeSessionID = id
        return session
    }

    private func activate(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        guard sessions[id] != nil else { return }
        activeSessionID = id
    }

    private func unregister(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        guard let session = sessions.removeValue(forKey: id) else { return }

        if let keyObserver = session.keyObserver {
            NotificationCenter.default.removeObserver(keyObserver)
        }
        if let moveObserver = session.moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
        }
        if let resizeObserver = session.resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
        if let closeObserver = session.closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        session.titleCancellable = nil
        sessionOrder.removeAll { $0 == id }

        if activeSessionID == id {
            activeSessionID = sessionOrder.last
        }
    }

    private func updateWindowTitle(_ window: NSWindow, store: ImageStore) {
        window.title = store.windowTitle
    }

    private func urlKey(_ url: URL) -> String {
        url.standardizedFileURL.path
    }
}
