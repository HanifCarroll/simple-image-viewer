import AppKit
import ImageIO
import SwiftUI

struct ThumbnailButton: View {
    let url: URL
    let selected: Bool
    let action: () -> Void
    @StateObject private var loader = ThumbnailLoader()

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.accentColor.opacity(0.22) : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 2 : 1)
                    )
                if let image = loader.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(7)
                }
            }
            .frame(width: 70, height: 70)
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 78, height: 78)
        .onAppear {
            loader.load(url)
        }
        .onChange(of: url) { _, newURL in
            loader.load(newURL)
        }
    }
}

private final class ThumbnailLoader: ObservableObject {
    @Published var image: NSImage?

    private static let cache = NSCache<NSURL, NSImage>()
    private var loadingURL: URL?

    func load(_ url: URL) {
        if loadingURL == url, image != nil {
            return
        }

        loadingURL = url
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        image = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let thumbnail = Self.makeThumbnail(for: url)
            DispatchQueue.main.async {
                guard let self, self.loadingURL == url else { return }
                if let thumbnail {
                    Self.cache.setObject(thumbnail, forKey: url as NSURL)
                }
                self.image = thumbnail
            }
        }
    }

    private static func makeThumbnail(for url: URL) -> NSImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 160
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
