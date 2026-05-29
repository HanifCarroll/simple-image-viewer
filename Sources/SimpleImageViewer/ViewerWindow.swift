import AppKit

final class ViewerWindow: NSWindow {
    weak var sessionCoordinator: ViewerSessionCoordinator?

    override func keyDown(with event: NSEvent) {
        if event.hasCommandOnlyModifier,
           event.charactersIgnoringModifiers?.lowercased() == "c",
           sessionCoordinator?.copyActiveWindowImageToPasteboard() == true {
            return
        }

        guard !event.hasViewerNavigationModifier else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 123:
            if sessionCoordinator?.navigate(-1, in: self) != true {
                super.keyDown(with: event)
            }
        case 124:
            if sessionCoordinator?.navigate(1, in: self) != true {
                super.keyDown(with: event)
            }
        default:
            super.keyDown(with: event)
        }
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .rightMouseDown,
              sessionCoordinator?.canCopyActiveWindowImage == true,
              let contentView
        else {
            super.sendEvent(event)
            return
        }

        let menu = NSMenu()
        let item = NSMenuItem(title: "Copy Image", action: #selector(copyImage), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: contentView)
    }

    @objc private func copyImage() {
        sessionCoordinator?.copyActiveWindowImageToPasteboard()
    }
}

extension NSEvent {
    var hasViewerNavigationModifier: Bool {
        !modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
    }

    var hasCommandOnlyModifier: Bool {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.command) &&
            !flags.contains(.control) &&
            !flags.contains(.option) &&
            !flags.contains(.shift)
    }

    var hasCommandZoomModifier: Bool {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.command) &&
            !flags.contains(.control) &&
            !flags.contains(.option)
    }
}
