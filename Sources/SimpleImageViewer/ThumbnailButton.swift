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

    private var loadingURL: URL?

    func load(_ url: URL) {
        if loadingURL == url, image != nil {
            return
        }

        loadingURL = url
        if let cached = ThumbnailCache.shared.image(for: url) {
            image = cached
            return
        }

        image = nil
        ThumbnailCache.shared.load(url) { [weak self] thumbnail in
            guard let self, self.loadingURL == url else { return }
            self.image = thumbnail
        }
    }
}

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()
    private let queue = DispatchQueue(label: "app.simple-image-viewer.thumbnails", qos: .userInitiated, attributes: .concurrent)
    private let lock = NSLock()
    private var inFlight: Set<URL> = []
    private var waiters: [URL: [(NSImage?) -> Void]] = [:]

    private init() {
        cache.countLimit = 600
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL, completion: @escaping (NSImage?) -> Void) {
        if let cached = image(for: url) {
            completion(cached)
            return
        }

        guard startLoading(url, completion: completion) else {
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            let thumbnail = Self.makeThumbnail(for: url)
            if let thumbnail {
                self.cache.setObject(thumbnail, forKey: url as NSURL)
            }
            let waiters = self.finishLoading(url)
            DispatchQueue.main.async {
                completion(thumbnail)
                waiters.forEach { $0(thumbnail) }
            }
        }
    }

    func preheat(_ urls: [URL]) {
        for url in urls where image(for: url) == nil && startPreheating(url) {
            queue.async { [weak self] in
                guard let self else { return }
                if let thumbnail = Self.makeThumbnail(for: url) {
                    self.cache.setObject(thumbnail, forKey: url as NSURL)
                }
                self.finishLoading(url)
            }
        }
    }

    func warmImmediately(_ urls: ArraySlice<URL>) {
        for url in urls where image(for: url) == nil && startPreheating(url) {
            if let thumbnail = Self.makeThumbnail(for: url) {
                cache.setObject(thumbnail, forKey: url as NSURL)
            }
            finishLoading(url).forEach { $0(image(for: url)) }
        }
    }

    private func startLoading(_ url: URL, completion: @escaping (NSImage?) -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !inFlight.contains(url) else {
            waiters[url, default: []].append(completion)
            return false
        }
        inFlight.insert(url)
        return true
    }

    private func startPreheating(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !inFlight.contains(url) else { return false }
        inFlight.insert(url)
        return true
    }

    @discardableResult
    private func finishLoading(_ url: URL) -> [(NSImage?) -> Void] {
        lock.lock()
        let callbacks = waiters.removeValue(forKey: url) ?? []
        inFlight.remove(url)
        lock.unlock()
        return callbacks
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
