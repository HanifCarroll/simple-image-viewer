import Foundation

private let supportedExtensions: Set<String> = [
    "png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tif", "tiff", "bmp"
]

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

func imageURLs(in folderURL: URL, options: FolderScanOptions = .nonRecursive) -> [URL] {
    let maxDepth = options.effectiveMaxDepth
    var urls: [URL] = []
    collectImages(in: folderURL, depth: 0, maxDepth: maxDepth, maxImages: options.maxImages, into: &urls)

    return urls
        .sorted { relativePath($0, from: folderURL).localizedStandardCompare(relativePath($1, from: folderURL)) == .orderedAscending }
}

func imageURLs(in summary: FolderScanSummary, options: FolderScanOptions) -> [URL] {
    let maxDepth = options.effectiveMaxDepth
    let maxImages = options.maxImages
    var urls: [URL] = []
    for image in summary.images where image.depth <= maxDepth {
        guard maxImages <= 0 || urls.count < maxImages else { break }
        urls.append(image.url)
    }

    return urls
        .sorted { relativePath($0, from: summary.rootURL).localizedStandardCompare(relativePath($1, from: summary.rootURL)) == .orderedAscending }
}

func scanFolder(_ folderURL: URL) -> FolderScanSummary {
    var foldersByDepth: [Int: Int] = [:]
    var imagesByDepth: [Int: Int] = [:]
    var images: [FolderScannedImage] = []
    collectSummary(
        in: folderURL,
        depth: 0,
        foldersByDepth: &foldersByDepth,
        imagesByDepth: &imagesByDepth,
        images: &images
    )

    let allDepths = Set(foldersByDepth.keys).union(imagesByDepth.keys)
    let levels = allDepths.sorted().map { depth in
        FolderDepthSummary(
            depth: depth,
            folderCount: foldersByDepth[depth, default: 0],
            imageCount: imagesByDepth[depth, default: 0]
        )
    }

    return FolderScanSummary(rootURL: folderURL, levels: levels, images: images)
}

extension FolderScanOptions {
    static let nonRecursive = FolderScanOptions(includeSubfolders: false, maxDepth: 0, maxImages: 0)
}

private func collectImages(in folderURL: URL, depth: Int, maxDepth: Int, maxImages: Int, into urls: inout [URL]) {
    guard maxImages <= 0 || urls.count < maxImages else { return }

    let entries = directoryEntries(in: folderURL)
    let files = entries.filter { isSupportedImage($0) }
    for file in files {
        guard maxImages <= 0 || urls.count < maxImages else { return }
        urls.append(file)
    }

    guard depth < maxDepth else { return }

    for folder in entries.filter({ isDirectory($0) }) {
        collectImages(in: folder, depth: depth + 1, maxDepth: maxDepth, maxImages: maxImages, into: &urls)
        guard maxImages <= 0 || urls.count < maxImages else { return }
    }
}

private func collectSummary(
    in folderURL: URL,
    depth: Int,
    foldersByDepth: inout [Int: Int],
    imagesByDepth: inout [Int: Int],
    images: inout [FolderScannedImage]
) {
    foldersByDepth[depth, default: 0] += 1

    let entries = directoryEntries(in: folderURL)
    let imageEntries = entries.filter { isSupportedImage($0) }
    imagesByDepth[depth, default: 0] += imageEntries.count
    images.append(contentsOf: imageEntries.map { FolderScannedImage(url: $0, depth: depth) })

    for folder in entries.filter({ isDirectory($0) }) {
        collectSummary(
            in: folder,
            depth: depth + 1,
            foldersByDepth: &foldersByDepth,
            imagesByDepth: &imagesByDepth,
            images: &images
        )
    }
}

private func directoryEntries(in folderURL: URL) -> [URL] {
    ((try? FileManager.default.contentsOfDirectory(
        at: folderURL,
        includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    )) ?? [])
    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

private func isSupportedImage(_ url: URL) -> Bool {
    supportedExtensions.contains(url.pathExtension.lowercased()) &&
        ((try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true)
}

private func isDirectory(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
}

private func relativePath(_ url: URL, from rootURL: URL) -> String {
    let rootPath = rootURL.standardizedFileURL.path
    let path = url.standardizedFileURL.path
    guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
    return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
}
