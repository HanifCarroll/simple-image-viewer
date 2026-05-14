import AppKit
import ImageIO

final class ImageLoadingTask {
    private let lock = NSLock()
    private let cancelHandler: () -> Void
    private var cancelled = false

    init(cancelHandler: @escaping () -> Void = {}) {
        self.cancelHandler = cancelHandler
    }

    func cancel() {
        lock.lock()
        let shouldCancel = !cancelled
        cancelled = true
        lock.unlock()

        if shouldCancel {
            cancelHandler()
        }
    }

    var isCancelled: Bool {
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value
    }
}

final class ImageLoadingService {
    static let shared = ImageLoadingService()

    private let displayCache = NSCache<NSURL, NSImage>()
    private let animatedCache = NSCache<NSURL, NSImage>()
    private let queue: OperationQueue

    private init() {
        displayCache.countLimit = 12
        animatedCache.countLimit = 4

        queue = OperationQueue()
        queue.name = "app.simple-image-viewer.full-size-images"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
    }

    func cachedDisplayImage(for url: URL) -> NSImage? {
        displayCache.object(forKey: url as NSURL)
    }

    @discardableResult
    func loadDisplayImage(for url: URL, completion: @escaping (NSImage?) -> Void) -> ImageLoadingTask {
        if let cached = cachedDisplayImage(for: url) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return ImageLoadingTask()
        }

        return load(url: url, cache: displayCache, completion: completion)
    }

    @discardableResult
    func loadAnimatedImage(for url: URL, completion: @escaping (NSImage?) -> Void) -> ImageLoadingTask {
        if let cached = animatedCache.object(forKey: url as NSURL) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return ImageLoadingTask()
        }

        return load(url: url, cache: animatedCache, completion: completion)
    }

    private func load(url: URL, cache: NSCache<NSURL, NSImage>, completion: @escaping (NSImage?) -> Void) -> ImageLoadingTask {
        var operation: BlockOperation?
        let task = ImageLoadingTask {
            operation?.cancel()
        }

        let block = BlockOperation { [weak task] in
            guard task?.isCancelled == false else { return }

            let image = NSImage(contentsOf: url)
            guard task?.isCancelled == false else { return }

            if let image {
                cache.setObject(image, forKey: url as NSURL)
            }

            DispatchQueue.main.async { [weak task] in
                guard task?.isCancelled == false else { return }
                completion(image)
            }
        }
        block.queuePriority = .veryHigh
        operation = block
        queue.addOperation(block)
        return task
    }
}

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()
    private let queue: OperationQueue
    private let lock = NSLock()
    private var operations: [URL: ThumbnailOperation] = [:]
    private var waiters: [URL: [(NSImage?) -> Void]] = [:]

    private init() {
        cache.countLimit = 600

        queue = OperationQueue()
        queue.name = "app.simple-image-viewer.thumbnails"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL, completion: @escaping (NSImage?) -> Void) {
        if let cached = image(for: url) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }

        schedule(url, priority: .veryHigh, completion: completion)
    }

    func preheat(_ urls: [URL]) {
        var seen = Set<URL>()
        let uniqueURLs = urls.filter { seen.insert($0).inserted }.prefix(96)
        let keepSet = Set(uniqueURLs)
        cancelPreheatingOutside(keepSet)

        for url in uniqueURLs where image(for: url) == nil {
            schedule(url, priority: .low, completion: nil)
        }
    }

    private func schedule(_ url: URL, priority: Operation.QueuePriority, completion: ((NSImage?) -> Void)?) {
        lock.lock()
        if let existing = operations[url] {
            if priority == .veryHigh {
                existing.operation.queuePriority = .veryHigh
            }
            if let completion {
                waiters[url, default: []].append(completion)
            }
            lock.unlock()
            return
        }

        var operation: BlockOperation?
        let task = ImageLoadingTask {
            operation?.cancel()
        }
        let block = BlockOperation { [weak self, weak task] in
            guard let self, task?.isCancelled == false else { return }

            let thumbnail = Self.makeThumbnail(for: url)
            guard task?.isCancelled == false else {
                self.finishLoading(url)
                return
            }

            if let thumbnail {
                self.cache.setObject(thumbnail, forKey: url as NSURL)
            }

            let callbacks = self.finishLoading(url)
            guard !callbacks.isEmpty else { return }

            DispatchQueue.main.async {
                callbacks.forEach { $0(thumbnail) }
            }
        }
        block.queuePriority = priority
        operation = block
        operations[url] = ThumbnailOperation(operation: block, task: task)
        if let completion {
            waiters[url, default: []].append(completion)
        }
        lock.unlock()

        queue.addOperation(block)
    }

    private func cancelPreheatingOutside(_ urls: Set<URL>) {
        lock.lock()
        let urlsToCancel = operations.keys.filter { url in
            !urls.contains(url) && (waiters[url]?.isEmpty ?? true)
        }
        let operationsToCancel = urlsToCancel.compactMap { operations[$0] }
        for url in urlsToCancel {
            operations.removeValue(forKey: url)
        }
        lock.unlock()

        operationsToCancel.forEach { $0.task.cancel() }
    }

    @discardableResult
    private func finishLoading(_ url: URL) -> [(NSImage?) -> Void] {
        lock.lock()
        let callbacks = waiters.removeValue(forKey: url) ?? []
        operations.removeValue(forKey: url)
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

private struct ThumbnailOperation {
    let operation: BlockOperation
    let task: ImageLoadingTask
}
