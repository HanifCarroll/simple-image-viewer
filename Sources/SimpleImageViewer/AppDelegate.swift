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
}
