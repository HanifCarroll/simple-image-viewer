import AppKit
import UniformTypeIdentifiers

final class ImageStore: ObservableObject {
    @Published private(set) var allImages: [URL] = []
    @Published var images: [URL] = []
    @Published var currentIndex = 0
    @Published var currentImage: NSImage?
    @Published var status = "Open an image or folder"
    @Published var zoomScale = 1.0
    @Published var panOffset = CGSize.zero
    @Published private var canvasSize = CGSize.zero
    @Published var includeSubfolders = false
    @Published var maxFolderDepth = 2
    @Published var maxPhotoCount = 0
    @Published var sortOption: ImageSortOption = .name {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    @Published var sortAscending = true {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    @Published var mediaKindFilter = MediaSupport.allKindsFilter {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    @Published var typeFilter = ImageListPresenter.allTypesFilter {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    @Published var nameFilter = "" {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    @Published var currentVideoDurationText = ""
    @Published var playbackCommandID = 0
    private var openGeneration = 0
    private var isProgressivelyLoading = false
    private var openCancellation: FolderDiscoveryCancellation?
    private var currentImageTask: ImageLoadingTask?
    private var viewportURL: URL?
    private var playbackPositions: [URL: Double] = [:]
    private let imagePadding: CGFloat = 24

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

    var availableMediaKindFilters: [String] {
        ImageListPresenter.availableMediaKindFilters(for: allImages)
    }

    var currentMediaKind: MediaKind? {
        currentURL?.mediaKind
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
        status = "Loading media..."
        cancelCurrentImageLoad()
        currentImage = nil
        currentVideoDurationText = ""
        images = []
        allImages = []
        currentIndex = 0
        isProgressivelyLoading = true
    }

    private var viewOptions: ImageViewOptions {
        ImageViewOptions(
            sortOption: sortOption,
            sortAscending: sortAscending,
            mediaKindFilter: mediaKindFilter,
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
            status = "No supported media found"
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
                status = "No supported media found"
            } else {
                loadCurrent()
            }
        } else if currentImage == nil {
            status = "Loading media..."
        }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.image, .movie]
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

    func zoomIn() {
        setZoomScale(zoomScale * 1.25)
    }

    func zoomOut() {
        setZoomScale(zoomScale / 1.25)
    }

    func resetZoom() {
        setZoomScale(1)
        panOffset = .zero
    }

    func togglePlayback() {
        guard currentURL?.isVideoForViewer == true else { return }
        playbackCommandID += 1
    }

    func updatePlaybackPosition(_ seconds: Double, for url: URL) {
        guard seconds.isFinite, seconds >= 0 else { return }
        playbackPositions[url.standardizedFileURL] = seconds
    }

    func playbackPosition(for url: URL) -> Double {
        playbackPositions[url.standardizedFileURL] ?? 0
    }

    func magnify(by amount: Double) {
        setZoomScale(zoomScale * (1 + amount))
    }

    func panBy(x: CGFloat, y: CGFloat) {
        guard zoomScale > 1 else { return }
        panOffset.width += x
        panOffset.height += y
        clampPanOffset()
    }

    func setCanvasSize(_ size: CGSize) {
        guard canvasSize != size else { return }
        canvasSize = size
        clampPanOffset()
    }

    private func loadCurrent() {
        guard let currentURL else { return }
        resetViewportIfNeeded(for: currentURL)
        cancelCurrentImageLoad()
        currentVideoDurationText = ""

        if currentURL.isVideoForViewer {
            currentImage = nil
            loadVideoDuration(for: currentURL)
        } else if currentURL.isGIFForViewer {
            currentImage = nil
        } else if let cached = ImageLoadingService.shared.cachedDisplayImage(for: currentURL) {
            currentImage = cached
        } else {
            currentImage = nil
            currentImageTask = ImageLoadingService.shared.loadDisplayImage(for: currentURL) { [weak self] image in
                guard let self, self.currentURL?.standardizedFileURL == currentURL.standardizedFileURL else { return }
                self.currentImage = image
                self.currentImageTask = nil
                self.clampPanOffset()
            }
        }
        let loadingSuffix = isProgressivelyLoading ? ", still scanning..." : ""
        status = "\(currentURL.lastPathComponent)  (\(currentIndex + 1) of \(images.count)\(loadingSuffix))"
    }

    private func loadVideoDuration(for url: URL) {
        VideoMetadataCache.shared.duration(for: url) { [weak self] seconds in
            guard let self, self.currentURL?.standardizedFileURL == url.standardizedFileURL else { return }
            self.currentVideoDurationText = seconds.map(MediaSupport.durationText(for:)) ?? ""
        }
    }

    private func setZoomScale(_ scale: Double) {
        let boundedScale = min(max(scale, 0.25), 8)
        zoomScale = boundedScale
        if boundedScale <= 1 {
            panOffset = .zero
        } else {
            clampPanOffset()
        }
    }

    private func resetViewportIfNeeded(for url: URL) {
        guard viewportURL?.standardizedFileURL != url.standardizedFileURL else { return }
        viewportURL = url
        zoomScale = 1
        panOffset = .zero
    }

    private func clampPanOffset() {
        guard zoomScale > 1,
              let currentImage,
              canvasSize.width > 0,
              canvasSize.height > 0
        else {
            if zoomScale <= 1 {
                panOffset = .zero
            }
            return
        }

        let fittedSize = fittedImageSize(for: currentImage.size, in: canvasSize)
        let maxX = max(0, (fittedSize.width * zoomScale - canvasSize.width) / 2)
        let maxY = max(0, (fittedSize.height * zoomScale - canvasSize.height) / 2)
        panOffset.width = min(max(panOffset.width, -maxX), maxX)
        panOffset.height = min(max(panOffset.height, -maxY), maxY)
    }

    private func fittedImageSize(for imageSize: CGSize, in canvasSize: CGSize) -> CGSize {
        let availableWidth = max(1, canvasSize.width - imagePadding * 2)
        let availableHeight = max(1, canvasSize.height - imagePadding * 2)
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: availableWidth, height: availableHeight)
        }

        let scale = min(availableWidth / imageSize.width, availableHeight / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
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
            currentVideoDurationText = ""
            status = "No media matches the current filters"
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
