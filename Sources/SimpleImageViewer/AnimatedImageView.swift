import AppKit
import SwiftUI

struct AnimatedImageView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSImageView {
        let imageView = FittingAnimatedNSImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageFrameStyle = .none
        imageView.canDrawSubviewsIntoLayer = true
        imageView.animates = true
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        context.coordinator.load(url, into: imageView)
    }

    final class Coordinator {
        private var loadingURL: URL?
        private var task: ImageLoadingTask?

        deinit {
            task?.cancel()
        }

        func load(_ url: URL, into imageView: NSImageView) {
            guard loadingURL != url else { return }

            loadingURL = url
            task?.cancel()
            imageView.image = nil
            imageView.animates = true

            task = ImageLoadingService.shared.loadAnimatedImage(for: url) { [weak self, weak imageView] image in
                guard let self, self.loadingURL == url, let imageView else { return }
                imageView.image = image
                imageView.animates = true
            }
        }
    }
}

private final class FittingAnimatedNSImageView: NSImageView {
    override var intrinsicContentSize: NSSize {
        .zero
    }
}
