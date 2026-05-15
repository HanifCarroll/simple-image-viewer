import AppKit

enum WindowFrameStore {
    private static let frameKey = "viewer.lastWindowFrame"
    private static let defaultFrame = NSRect(x: 0, y: 0, width: 1100, height: 760)

    static var initialFrame: NSRect {
        guard let frameString = UserDefaults.standard.string(forKey: frameKey) else {
            return defaultFrame
        }

        let frame = NSRectFromString(frameString)
        guard frame.width >= 760, frame.height >= 520 else {
            return defaultFrame
        }

        return fit(frame, to: NSScreen.screens.map(\.visibleFrame))
    }

    static func save(_ frame: NSRect) {
        guard frame.width >= 760, frame.height >= 520 else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: frameKey)
    }

    private static func fit(_ frame: NSRect, to visibleFrames: [NSRect]) -> NSRect {
        guard !visibleFrames.contains(where: { $0.intersects(frame) }) else {
            return frame
        }

        let visibleFrame = NSScreen.main?.visibleFrame ?? visibleFrames.first ?? defaultFrame
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)
        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }
}
