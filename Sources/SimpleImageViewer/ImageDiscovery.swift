import Foundation

private let summaryImageIndexLimit = 20_000
private let summaryMaximumDepth = 64

struct FolderScanOptions {
    var includeSubfolders: Bool
    var maxDepth: Int
    var maxImages: Int

    var effectiveMaxDepth: Int {
        includeSubfolders ? max(0, maxDepth) : 0
    }
}

struct FolderDepthSummary: Identifiable {
    let depth: Int
    let folderCount: Int
    let imageCount: Int

    var id: Int { depth }
}

struct FolderScannedImage {
    let url: URL
    let depth: Int
}

struct FolderScanSummary {
    let rootURL: URL
    let levels: [FolderDepthSummary]
    let images: [FolderScannedImage]
    let isImageIndexComplete: Bool
    let wasCancelled: Bool

    var deepestLevel: Int {
        levels.map(\.depth).max() ?? 0
    }

    var totalImages: Int {
        images.count
    }

    var totalFolders: Int {
        levels.reduce(0) { $0 + $1.folderCount }
    }
}

extension FolderScanSummary: Identifiable {
    var id: URL { rootURL }
}

final class FolderDiscoveryCancellation {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

func imageURLs(
    in folderURL: URL,
    options: FolderScanOptions = .nonRecursive,
    cancellation: FolderDiscoveryCancellation? = nil
) -> [URL] {
    let scanner = FolderDiscoveryScanner(
        rootURL: folderURL,
        maximumDepth: options.effectiveMaxDepth,
        maxImages: options.maxImages,
        maxIndexedImages: nil,
        cancellation: cancellation
    )
    let summary = scanner.scan(batchSize: 0)
    return sortedImageURLs(summary.images.map(\.url), from: folderURL)
}

func imageURLs(in summary: FolderScanSummary, options: FolderScanOptions) -> [URL] {
    let maxDepth = options.effectiveMaxDepth
    let maxImages = options.maxImages
    let indexedImages = summary.images.filter { $0.depth <= maxDepth }
    if summary.isImageIndexComplete || maxImages > 0 && indexedImages.count >= maxImages {
        let limitedImages = maxImages > 0 ? Array(indexedImages.prefix(maxImages)) : indexedImages
        return sortedImageURLs(limitedImages.map(\.url), from: summary.rootURL)
    }

    return imageURLs(in: summary.rootURL, options: options)
}

func enumerateImageURLBatches(
    in folderURL: URL,
    options: FolderScanOptions = .nonRecursive,
    batchSize: Int = 64,
    cancellation: FolderDiscoveryCancellation? = nil,
    onBatch: @escaping ([URL], Bool) -> Void
) {
    let scanner = FolderDiscoveryScanner(
        rootURL: folderURL,
        maximumDepth: options.effectiveMaxDepth,
        maxImages: options.maxImages,
        maxIndexedImages: 0,
        cancellation: cancellation
    )
    _ = scanner.scan(batchSize: batchSize, onBatch: onBatch)
}

func scanFolder(_ folderURL: URL, cancellation: FolderDiscoveryCancellation? = nil) -> FolderScanSummary {
    let scanner = FolderDiscoveryScanner(
        rootURL: folderURL,
        maximumDepth: summaryMaximumDepth,
        maxImages: 0,
        maxIndexedImages: summaryImageIndexLimit,
        cancellation: cancellation
    )
    return scanner.scan(batchSize: 0)
}

extension FolderScanOptions {
    static let nonRecursive = FolderScanOptions(includeSubfolders: false, maxDepth: 0, maxImages: 0)
}

private final class FolderDiscoveryScanner {
    private struct DirectoryItem {
        let url: URL
        let depth: Int
    }

    private struct LevelCounts {
        var folders = 0
        var images = 0
    }

    private let rootURL: URL
    private let maximumDepth: Int
    private let maxImages: Int
    private let maxIndexedImages: Int?
    private let cancellation: FolderDiscoveryCancellation?

    private var levels: [Int: LevelCounts] = [:]
    private var images: [FolderScannedImage] = []
    private var visitedDirectoryPaths: Set<String> = []
    private var discoveredImageCount = 0
    private var imageIndexComplete = true

    init(
        rootURL: URL,
        maximumDepth: Int,
        maxImages: Int,
        maxIndexedImages: Int?,
        cancellation: FolderDiscoveryCancellation?
    ) {
        self.rootURL = rootURL
        self.maximumDepth = max(0, maximumDepth)
        self.maxImages = max(0, maxImages)
        self.maxIndexedImages = maxIndexedImages.map { max(0, $0) }
        self.cancellation = cancellation
    }

    func scan(batchSize: Int, onBatch: (([URL], Bool) -> Void)? = nil) -> FolderScanSummary {
        let batchCapacity = max(0, batchSize)
        let shouldBatch = onBatch != nil && batchCapacity > 0
        var batch: [URL] = []

        func flush(finished: Bool) {
            guard let onBatch else { return }
            guard !batch.isEmpty || finished else { return }
            let currentBatch = batch
            batch.removeAll(keepingCapacity: true)
            onBatch(currentBatch, finished)
        }

        var stack = [DirectoryItem(url: rootURL, depth: 0)]
        while let item = stack.popLast() {
            guard !isCancelled else { break }
            guard maxImages <= 0 || discoveredImageCount < maxImages else { break }
            guard markDirectoryVisited(item.url) else { continue }

            levels[item.depth, default: LevelCounts()].folders += 1
            let entries = directoryEntries(in: item.url)
            for imageURL in entries where MediaSupport.isSupportedFile(imageURL) {
                guard !isCancelled else { break }
                guard maxImages <= 0 || discoveredImageCount < maxImages else { break }
                discoveredImageCount += 1
                levels[item.depth, default: LevelCounts()].images += 1
                indexImage(FolderScannedImage(url: imageURL, depth: item.depth))
                if shouldBatch {
                    batch.append(imageURL)
                }
                if shouldBatch && batch.count >= batchCapacity {
                    flush(finished: false)
                }
            }

            guard !isCancelled else { break }
            guard item.depth < maximumDepth else { continue }
            let childFolders = entries.filter { isTraversableDirectory($0) }
            for folderURL in childFolders.reversed() {
                stack.append(DirectoryItem(url: folderURL, depth: item.depth + 1))
            }
        }

        flush(finished: !isCancelled)
        return makeSummary(wasCancelled: isCancelled)
    }

    private var isCancelled: Bool {
        cancellation?.isCancelled == true
    }

    private func indexImage(_ image: FolderScannedImage) {
        guard let maxIndexedImages else {
            images.append(image)
            return
        }

        guard maxIndexedImages > 0, images.count < maxIndexedImages else {
            imageIndexComplete = false
            return
        }

        images.append(image)
    }

    private func markDirectoryVisited(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return visitedDirectoryPaths.insert(path).inserted
    }

    private func makeSummary(wasCancelled: Bool) -> FolderScanSummary {
        let summaryLevels = levels.keys.sorted().map { depth in
            let counts = levels[depth, default: LevelCounts()]
            return FolderDepthSummary(
                depth: depth,
                folderCount: counts.folders,
                imageCount: counts.images
            )
        }
        return FolderScanSummary(
            rootURL: rootURL,
            levels: summaryLevels,
            images: images,
            isImageIndexComplete: imageIndexComplete,
            wasCancelled: wasCancelled
        )
    }
}

private func directoryEntries(in folderURL: URL) -> [URL] {
    ((try? FileManager.default.contentsOfDirectory(
        at: folderURL,
        includingPropertiesForKeys: [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isPackageKey
        ],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    )) ?? [])
    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

private func isTraversableDirectory(_ url: URL) -> Bool {
    let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey])
    return values?.isDirectory == true &&
        values?.isSymbolicLink != true &&
        values?.isPackage != true
}

private func sortedImageURLs(_ urls: [URL], from rootURL: URL) -> [URL] {
    urls.sorted {
        relativePath($0, from: rootURL).localizedStandardCompare(relativePath($1, from: rootURL)) == .orderedAscending
    }
}

private func relativePath(_ url: URL, from rootURL: URL) -> String {
    let rootPath = rootURL.standardizedFileURL.path
    let path = url.standardizedFileURL.path
    guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
    return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
}
