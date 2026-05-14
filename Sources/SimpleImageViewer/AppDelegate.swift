import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var store: ImageStore?
    private var pendingURL: URL?

    func attach(_ store: ImageStore) {
        self.store = store
        if let pendingURL {
            store.open(pendingURL)
            self.pendingURL = nil
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
        let url = URL(fileURLWithPath: filename)
        if let store {
            store.open(url)
        } else {
            pendingURL = url
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
