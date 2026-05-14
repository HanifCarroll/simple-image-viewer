import AppKit

final class ViewerWindow: NSWindow {
    weak var sessionCoordinator: ViewerSessionCoordinator?

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 123:
            sessionCoordinator?.navigate(-1, in: self)
        case 124:
            sessionCoordinator?.navigate(1, in: self)
        default:
            super.keyDown(with: event)
        }
    }
}
