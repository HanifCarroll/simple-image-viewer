import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var store: ImageStore?
    private var pendingURLs: [URL] = []
    private var viewerWindows: [NSWindowController] = []
    private var usedInitialWindowForExternalOpen = false

    func attach(_ store: ImageStore) {
        self.store = store
        if !pendingURLs.isEmpty {
            openURLs(pendingURLs)
            pendingURLs.removeAll()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            self.fitWindowsToVisibleScreen()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.fitWindowsToVisibleScreen()
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openURLs([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        openURLs(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openURLs(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func openURLs(_ urls: [URL]) {
        guard let store else {
            pendingURLs.append(contentsOf: urls)
            return
        }

        var urlsToOpen = urls
        if !store.hasOpenedContent, !usedInitialWindowForExternalOpen, let firstURL = urlsToOpen.first {
            usedInitialWindowForExternalOpen = true
            store.open(firstURL)
            urlsToOpen.removeFirst()
        }

        for url in urlsToOpen {
            openInIndependentWindow(url)
        }
    }

    private func openInIndependentWindow(_ url: URL) {
        let store = ImageStore()
        let contentView = ContentView(store: store)
            .frame(minWidth: 760, idealWidth: 1100, minHeight: 520, idealHeight: 760)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Simple Image Viewer"
        window.contentViewController = NSHostingController(rootView: contentView)
        window.delegate = self
        window.center()

        let controller = NSWindowController(window: window)
        viewerWindows.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        store.open(url)
    }

    private func fitWindowsToVisibleScreen() {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return }
        for window in NSApp.windows where window.isVisible {
            let maxWidth = visibleFrame.width - 40
            let maxHeight = visibleFrame.height - 40
            let isTooLarge = window.frame.width > maxWidth || window.frame.height > maxHeight
            let isOffscreen = window.frame.minX < visibleFrame.minX ||
                window.frame.maxX > visibleFrame.maxX ||
                window.frame.minY < visibleFrame.minY ||
                window.frame.maxY > visibleFrame.maxY
            guard isTooLarge || isOffscreen else { continue }

            let width = min(window.frame.width, maxWidth)
            let height = min(window.frame.height, maxHeight)
            let x = visibleFrame.midX - width / 2
            let y = visibleFrame.midY - height / 2
            window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        viewerWindows.removeAll { $0.window === window }
    }
}
