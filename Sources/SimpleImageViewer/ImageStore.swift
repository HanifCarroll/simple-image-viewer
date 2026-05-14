import AppKit
import UniformTypeIdentifiers

final class ImageStore: ObservableObject {
    @Published private(set) var allImages: [URL] = []
    @Published var images: [URL] = []
    @Published var currentIndex = 0
    @Published var currentImage: NSImage?
    @Published var status = "Open an image or folder"
    @Published var includeSubfolders = false
    @Published var maxFolderDepth = 2
    @Published var maxPhotoCount = 0
    @Published var sortOption: ImageSortOption = .name {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    @Published var sortAscending = true {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    @Published var typeFilter = ImageListPresenter.allTypesFilter {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    @Published var nameFilter = "" {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    private var openGeneration = 0
    private var isProgressivelyLoading = false
    private var openCancellation: FolderDiscoveryCancellation?
    private var currentImageTask: ImageLoadingTask?

    var currentURL: URL? {
        images.indices.contains(currentIndex) ? images[currentIndex] : nil
    }

    var windowTitle: String {
        currentURL?.lastPathComponent ?? "Simple Image Viewer"
    }

    var hasOpenedContent: Bool {
        !allImages.isEmpty || !images.isEmpty || currentImage != nil
    }

    var availableTypeFilters: [String] {
        ImageListPresenter.availableTypeFilters(for: allImages)
    }

    func open(_ url: URL) {
        let (cancellation, generation) = beginOpenOperation()
        let plan = ImageOpeningService.plan(for: url, options: folderScanOptions, cancellation: cancellation)
        resetForOpening()

        ImageOpeningService.loadBatches(for: plan) { [weak self] batch, finished in
            guard let self, self.openGeneration == generation else { return }
            self.receiveImageBatch(batch, sourceURL: plan.sourceURL, finished: finished)
        }
    }

    private func beginOpenOperation() -> (FolderDiscoveryCancellation, Int) {
        openCancellation?.cancel()
        let cancellation = FolderDiscoveryCancellation()
        openCancellation = cancellation
        openGeneration += 1
        return (cancellation, openGeneration)
    }

    private func invalidateOpenOperation() {
        openCancellation?.cancel()
        openCancellation = nil
        openGeneration += 1
    }

    private func resetForOpening() {
        status = "Loading images..."
        cancelCurrentImageLoad()
        currentImage = nil
        images = []
        allImages = []
        currentIndex = 0
        isProgressivelyLoading = true
    }

    private var viewOptions: ImageViewOptions {
        ImageViewOptions(
            sortOption: sortOption,
            sortAscending: sortAscending,
            typeFilter: typeFilter,
            nameFilter: nameFilter
        )
    }

    private var usesDefaultViewOptions: Bool {
        viewOptions.usesDefaultProjection
    }

    private func applyOpenedImages(_ urls: [URL], preferredURL: URL?) {
        if usesDefaultViewOptions {
            images = urls
            if let preferredURL,
               let index = images.firstIndex(where: { $0.standardizedFileURL == preferredURL.standardizedFileURL }) {
                currentIndex = index
            } else {
                currentIndex = 0
            }
            CurrentImagePresenter.warmInitialThumbnails(images: images, currentIndex: currentIndex)
            loadCurrent()
        } else {
            applyViewOptions(preserving: preferredURL)
        }
    }

    private func displayFirstBatchIfNeeded(sourceURL: URL, wasEmpty: Bool) {
        guard wasEmpty else {
            updateLoadingStatus()
            return
        }

        if !sourceURL.hasDirectoryPath,
           let index = images.firstIndex(where: { $0.standardizedFileURL == sourceURL.standardizedFileURL }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        CurrentImagePresenter.warmInitialThumbnails(images: images, currentIndex: currentIndex)
        loadCurrent()
    }

    private func finishOpen(_ url: URL, urls: [URL]) {
        isProgressivelyLoading = false
        guard !urls.isEmpty else {
            images = []
            allImages = []
            currentIndex = 0
            cancelCurrentImageLoad()
            currentImage = nil
            status = "No supported images found"
            return
        }

        allImages = urls
        applyOpenedImages(urls, preferredURL: url.hasDirectoryPath ? nil : url)
    }

    private func receiveImageBatch(_ batch: [URL], sourceURL: URL, finished: Bool) {
        if !batch.isEmpty {
            allImages.append(contentsOf: batch)

            if usesDefaultViewOptions {
                let wasEmpty = images.isEmpty
                images.append(contentsOf: batch)
                displayFirstBatchIfNeeded(sourceURL: sourceURL, wasEmpty: wasEmpty)
            } else {
                applyViewOptions(preserving: currentURL)
            }
        }

        if finished {
            isProgressivelyLoading = false
            if images.isEmpty {
                cancelCurrentImageLoad()
                currentImage = nil
                status = "No supported images found"
            } else {
                loadCurrent()
            }
        } else if currentImage == nil {
            status = "Loading images..."
        }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.image]
        panel.prompt = "Open"
        let accessoryModel = FolderOpenAccessoryModel(
            includeSubfolders: includeSubfolders,
            maxFolderDepth: maxFolderDepth,
            maxPhotoCount: maxPhotoCount
        )
        let accessoryView = FolderOpenAccessoryView(model: accessoryModel)
        let panelDelegate = FolderOpenPanelDelegate(accessoryView: accessoryView)
        panel.delegate = panelDelegate
        panel.accessoryView = accessoryView
        panel.isAccessoryViewDisclosed = true
        panel.setContentSize(NSSize(width: 1_120, height: 720))
        accessoryView.updateSelection(panel.url ?? panel.directoryURL)
        let result = withExtendedLifetime(panelDelegate) {
            panel.runModal()
        }
        if result == .OK, let url = panel.url {
            let folderURL = ImageOpeningService.folderURL(for: url)
            includeSubfolders = accessoryModel.includeSubfolders
            maxFolderDepth = accessoryModel.maxFolderDepth
            maxPhotoCount = accessoryModel.maxPhotoCount
            if let summary = accessoryModel.summary, summary.rootURL.standardizedFileURL == folderURL.standardizedFileURL {
                invalidateOpenOperation()
                finishOpen(url, urls: imageURLs(in: summary, options: folderScanOptions))
            } else {
                open(url)
            }
        }
    }

    func navigate(_ delta: Int) {
        let next = currentIndex + delta
        guard images.indices.contains(next) else { return }
        currentIndex = next
        loadCurrent()
    }

    func select(_ index: Int) {
        guard images.indices.contains(index) else { return }
        currentIndex = index
        loadCurrent()
    }

    func toggleSortDirection() {
        sortAscending.toggle()
    }

    func clearNameFilter() {
        nameFilter = ""
    }

    private func loadCurrent() {
        guard let currentURL else { return }
        cancelCurrentImageLoad()

        if currentURL.isGIFForViewer {
            currentImage = nil
        } else if let cached = ImageLoadingService.shared.cachedDisplayImage(for: currentURL) {
            currentImage = cached
        } else {
            currentImage = nil
            currentImageTask = ImageLoadingService.shared.loadDisplayImage(for: currentURL) { [weak self] image in
                guard let self, self.currentURL?.standardizedFileURL == currentURL.standardizedFileURL else { return }
                self.currentImage = image
                self.currentImageTask = nil
            }
        }
        let loadingSuffix = isProgressivelyLoading ? ", still scanning..." : ""
        status = "\(currentURL.lastPathComponent)  (\(currentIndex + 1) of \(images.count)\(loadingSuffix))"
    }

    private func cancelCurrentImageLoad() {
        currentImageTask?.cancel()
        currentImageTask = nil
    }

    private func updateLoadingStatus() {
        status = CurrentImagePresenter.loadingStatus(
            for: currentURL,
            index: currentIndex,
            visibleCount: images.count
        )
    }

    private var folderScanOptions: FolderScanOptions {
        FolderScanOptions(
            includeSubfolders: includeSubfolders,
            maxDepth: maxFolderDepth,
            maxImages: maxPhotoCount
        )
    }

    private func applyViewOptions(preserving preferredURL: URL?) {
        guard !allImages.isEmpty else { return }

        images = ImageListPresenter.project(allImages, using: viewOptions)
        guard !images.isEmpty else {
            currentIndex = 0
            currentImage = nil
            status = "No images match the current filters"
            return
        }
        if let preferredURL,
           let index = images.firstIndex(where: { $0.standardizedFileURL == preferredURL.standardizedFileURL }) {
            currentIndex = index
        } else {
            currentIndex = min(currentIndex, max(images.count - 1, 0))
        }
        CurrentImagePresenter.warmInitialThumbnails(images: images, currentIndex: currentIndex)
        loadCurrent()
    }
}

private extension URL {
    var isGIFForViewer: Bool {
        pathExtension.caseInsensitiveCompare("gif") == .orderedSame
    }
}
