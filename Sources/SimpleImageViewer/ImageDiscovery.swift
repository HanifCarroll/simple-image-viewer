import Foundation

private let supportedExtensions: Set<String> = [
    "png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tif", "tiff", "bmp"
]

func imageURLs(in folderURL: URL) -> [URL] {
    let urls = (try? FileManager.default.contentsOfDirectory(
        at: folderURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )) ?? []

    return urls
        .filter { url in
            supportedExtensions.contains(url.pathExtension.lowercased()) &&
                ((try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true)
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}
