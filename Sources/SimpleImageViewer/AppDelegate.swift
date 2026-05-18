import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionCoordinator = ViewerSessionCoordinator()
    private var keyEventMonitor: Any?

    override init() {
        super.init()
        sessionCoordinator.queueLaunchURLs(Self.launchArgumentURLs())
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
        DispatchQueue.main.async {
            self.sessionCoordinator.openInitialWindow()
            self.fitWindowsToVisibleScreen()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sessionCoordinator.closeUnmanagedWindows()
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

    func openPanelInNewWindow() {
        sessionCoordinator.openPanelInNewWindow()
    }

    func openActiveWindowPanel() {
        sessionCoordinator.openActiveWindowPanel()
    }

    func openNewViewerWindow() {
        sessionCoordinator.openNewViewerWindow()
    }

    func navigateActiveWindow(_ delta: Int) {
        sessionCoordinator.navigateActiveWindow(delta)
    }

    func zoomActiveWindowIn() {
        sessionCoordinator.zoomActiveWindowIn()
    }

    func zoomActiveWindowOut() {
        sessionCoordinator.zoomActiveWindowOut()
    }

    func toggleActiveWindowPlayback() {
        sessionCoordinator.toggleActiveWindowPlayback()
    }

    func selectFirstInActiveWindow() {
        sessionCoordinator.selectFirstInActiveWindow()
    }

    func selectLastInActiveWindow() {
        sessionCoordinator.selectLastInActiveWindow()
    }

    deinit {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
    }

    private func openURLs(_ urls: [URL]) {
        sessionCoordinator.open(urls)
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if event.hasCommandZoomModifier {
            switch event.charactersIgnoringModifiers {
            case "=", "+":
                sessionCoordinator.zoomActiveWindowIn()
                return nil
            case "-":
                sessionCoordinator.zoomActiveWindowOut()
                return nil
            default:
                break
            }

            switch event.keyCode {
            case 24:
                sessionCoordinator.zoomActiveWindowIn()
                return nil
            case 27:
                sessionCoordinator.zoomActiveWindowOut()
                return nil
            case 69:
                sessionCoordinator.zoomActiveWindowIn()
                return nil
            case 78:
                sessionCoordinator.zoomActiveWindowOut()
                return nil
            default:
                break
            }
        }

        guard !event.hasViewerNavigationModifier else {
            return event
        }

        guard !isTextInputActive(in: event.window ?? NSApp.keyWindow) else {
            return event
        }

        switch event.keyCode {
        case 49:
            sessionCoordinator.toggleActiveWindowPlayback()
            return nil
        case 123:
            return sessionCoordinator.navigate(-1, in: event.window ?? NSApp.keyWindow) ? nil : event
        case 124:
            return sessionCoordinator.navigate(1, in: event.window ?? NSApp.keyWindow) ? nil : event
        default:
            return event
        }
    }

    private func isTextInputActive(in window: NSWindow?) -> Bool {
        window?.firstResponder is NSTextView
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

private extension AppDelegate {
    static func launchArgumentURLs() -> [URL] {
        CommandLine.arguments
            .dropFirst()
            .filter { !$0.hasPrefix("-") }
            .map { URL(fileURLWithPath: $0) }
    }
}
