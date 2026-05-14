import AppKit
import SwiftUI

struct AnimatedImageView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageFrameStyle = .none
        imageView.canDrawSubviewsIntoLayer = true
        imageView.animates = true
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        imageView.image = NSImage(contentsOf: url)
        imageView.animates = true
    }
}
