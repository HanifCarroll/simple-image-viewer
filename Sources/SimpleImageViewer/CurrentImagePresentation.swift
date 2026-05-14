import AppKit

struct CurrentImageDisplay {
    let image: NSImage?
    let status: String
}

enum CurrentImagePresenter {
    static func loadCurrentImage(
        at url: URL,
        index: Int,
        visibleCount: Int,
        isProgressivelyLoading: Bool
    ) -> CurrentImageDisplay {
        let image = NSImage(contentsOf: url)
        return CurrentImageDisplay(
            image: image,
            status: status(for: url, index: index, visibleCount: visibleCount, isProgressivelyLoading: isProgressivelyLoading)
        )
    }

    static func loadingStatus(
        for url: URL?,
        index: Int,
        visibleCount: Int
    ) -> String {
        guard let url else {
            return "Loaded \(visibleCount) images, still scanning..."
        }
        return status(for: url, index: index, visibleCount: visibleCount, isProgressivelyLoading: true)
    }

    static func warmInitialThumbnails(images: [URL], currentIndex: Int) {
        guard !images.isEmpty else { return }
        let startIndex = max(images.startIndex, currentIndex - 4)
        let endIndex = min(images.index(before: images.endIndex), currentIndex + 12)
        ThumbnailCache.shared.preheat(Array(images[startIndex...endIndex]))
    }

    private static func status(
        for url: URL,
        index: Int,
        visibleCount: Int,
        isProgressivelyLoading: Bool
    ) -> String {
        let loadingSuffix = isProgressivelyLoading ? ", still scanning..." : ""
        return "\(url.lastPathComponent)  (\(index + 1) of \(visibleCount)\(loadingSuffix))"
    }
}
