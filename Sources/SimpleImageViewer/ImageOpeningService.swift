import Foundation

struct ImageOpenPlan {
    let sourceURL: URL
    let folderURL: URL
    let scanOptions: FolderScanOptions
    let cancellation: FolderDiscoveryCancellation
}

enum ImageOpeningService {
    static func plan(
        for url: URL,
        options: FolderScanOptions,
        cancellation: FolderDiscoveryCancellation
    ) -> ImageOpenPlan {
        ImageOpenPlan(
            sourceURL: url,
            folderURL: folderURL(for: url),
            scanOptions: options,
            cancellation: cancellation
        )
    }

    static func folderURL(for url: URL) -> URL {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return url
        }
        return url.deletingLastPathComponent()
    }

    static func loadBatches(
        for plan: ImageOpenPlan,
        onBatch: @escaping ([URL], Bool) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            enumerateImageURLBatches(
                in: plan.folderURL,
                options: plan.scanOptions,
                cancellation: plan.cancellation
            ) { batch, finished in
                DispatchQueue.main.async {
                    onBatch(batch, finished)
                }
            }
        }
    }
}
