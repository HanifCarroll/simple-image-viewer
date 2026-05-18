import Foundation

enum CurrentImagePresenter {
    static func loadingStatus(
        for url: URL?,
        index: Int,
        visibleCount: Int
    ) -> String {
        guard let url else {
            return "Loaded \(visibleCount) media files, still scanning..."
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
