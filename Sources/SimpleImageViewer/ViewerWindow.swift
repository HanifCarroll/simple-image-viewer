import AppKit

final class ViewerWindow: NSWindow {
    weak var sessionCoordinator: ViewerSessionCoordinator?

    override func keyDown(with event: NSEvent) {
        if event.hasCommandOnlyModifier,
           event.charactersIgnoringModifiers?.lowercased() == "c",
           sessionCoordinator?.copyActiveWindowImageToPasteboard() == true {
            return
        }

        if event.hasCommandOnlyModifier {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "l":
                if sessionCoordinator?.rotateImage(clockwise: false, in: self) == true {
                    return
                }
            case "r":
                if sessionCoordinator?.rotateImage(clockwise: true, in: self) == true {
                    return
                }
            default:
                break
            }
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
        let canCopy = sessionCoordinator?.canCopyImage(in: self) == true
        let canRotate = sessionCoordinator?.canRotateImage(in: self) == true
        guard event.type == .rightMouseDown,
              canCopy || canRotate,
              let contentView
        else {
            super.sendEvent(event)
            return
        }

        let menu = NSMenu()
        if canRotate {
            let rotateLeft = NSMenuItem(title: "Rotate Left", action: #selector(rotateLeft), keyEquivalent: "")
            rotateLeft.target = self
            menu.addItem(rotateLeft)

            let rotateRight = NSMenuItem(title: "Rotate Right", action: #selector(rotateRight), keyEquivalent: "")
            rotateRight.target = self
            menu.addItem(rotateRight)
        }

        if canCopy {
            if canRotate {
                menu.addItem(.separator())
            }
            let item = NSMenuItem(title: "Copy Image", action: #selector(copyImage), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: contentView)
    }

    @objc private func copyImage() {
        sessionCoordinator?.copyActiveWindowImageToPasteboard()
    }

    @objc private func rotateLeft() {
        sessionCoordinator?.rotateImage(clockwise: false, in: self)
    }

    @objc private func rotateRight() {
        sessionCoordinator?.rotateImage(clockwise: true, in: self)
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
