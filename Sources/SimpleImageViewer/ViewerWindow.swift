import AppKit

final class ViewerWindow: NSWindow {
    weak var sessionCoordinator: ViewerSessionCoordinator?

    override func keyDown(with event: NSEvent) {
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
}

extension NSEvent {
    var hasViewerNavigationModifier: Bool {
        !modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
    }
}
