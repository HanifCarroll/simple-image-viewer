import AppKit

enum ImageRotation {
    static func normalizedQuarterTurns(_ quarterTurns: Int) -> Int {
        let remainder = quarterTurns % 4
        return remainder >= 0 ? remainder : remainder + 4
    }

    static func rotated(_ image: NSImage, quarterTurns: Int) -> NSImage {
        let turns = normalizedQuarterTurns(quarterTurns)
        guard turns != 0 else { return image }

        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return image }

        let rotatedSize = turns.isMultiple(of: 2)
            ? originalSize
            : NSSize(width: originalSize.height, height: originalSize.width)

        let rotatedImage = NSImage(size: rotatedSize)
        rotatedImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        let transform = NSAffineTransform()
        transform.translateX(by: rotatedSize.width / 2, yBy: rotatedSize.height / 2)
        // Positive quarter turns are clockwise on screen (SwiftUI's y-down rotationEffect).
        // AppKit's y-up context rotates positive angles counterclockwise, so negate here.
        transform.rotate(byDegrees: CGFloat(-turns * 90))
        transform.translateX(by: -originalSize.width / 2, yBy: -originalSize.height / 2)
        transform.concat()

        image.draw(
            in: NSRect(origin: .zero, size: originalSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1
        )
        rotatedImage.unlockFocus()

        return rotatedImage
    }
}
