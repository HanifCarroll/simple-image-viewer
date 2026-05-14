import AppKit
import UniformTypeIdentifiers

enum ImageSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case folderPath = "Folder"
    case dateModified = "Date Modified"
    case fileType = "File Type"

    var id: Self { self }
}

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
    @Published var typeFilter = "All" {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    @Published var nameFilter = "" {
        didSet { applyViewOptions(preserving: currentURL) }
    }
    private var openGeneration = 0
    private var isProgressivelyLoading = false
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
        let extensions = Set(allImages.map { normalizedType($0) })
        return ["All"] + extensions.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func open(_ url: URL) {
        let folderURL: URL
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            folderURL = url
        } else {
            folderURL = url.deletingLastPathComponent()
        }

        openGeneration += 1
        let generation = openGeneration
        let options = folderScanOptions
        status = "Loading images..."
        cancelCurrentImageLoad()
        currentImage = nil
        images = []
        allImages = []
        currentIndex = 0
        isProgressivelyLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            enumerateImageURLBatches(in: folderURL, options: options) { batch, finished in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.openGeneration == generation else { return }
                    self.receiveImageBatch(batch, sourceURL: url, finished: finished)
                }
            }
        }
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
        if usesDefaultViewOptions {
            images = urls
            if !url.hasDirectoryPath,
               let index = images.firstIndex(where: { $0.standardizedFileURL == url.standardizedFileURL }) {
                currentIndex = index
            } else {
                currentIndex = 0
            }
            warmInitialThumbnails()
            loadCurrent()
        } else {
            applyViewOptions(preserving: url.hasDirectoryPath ? nil : url)
        }
    }

    private func receiveImageBatch(_ batch: [URL], sourceURL: URL, finished: Bool) {
        if !batch.isEmpty {
            allImages.append(contentsOf: batch)

            if usesDefaultViewOptions {
                let wasEmpty = images.isEmpty
                images.append(contentsOf: batch)
                if wasEmpty {
                    if !sourceURL.hasDirectoryPath,
                       let index = images.firstIndex(where: { $0.standardizedFileURL == sourceURL.standardizedFileURL }) {
                        currentIndex = index
                    } else {
                        currentIndex = 0
                    }
                    warmInitialThumbnails()
                    loadCurrent()
                } else {
                    updateLoadingStatus()
                }
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
            let folderURL = folderURL(for: url)
            includeSubfolders = accessoryModel.includeSubfolders
            maxFolderDepth = accessoryModel.maxFolderDepth
            maxPhotoCount = accessoryModel.maxPhotoCount
            if let summary = accessoryModel.summary, summary.rootURL.standardizedFileURL == folderURL.standardizedFileURL {
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
        if let currentURL {
            status = "\(currentURL.lastPathComponent)  (\(currentIndex + 1) of \(images.count), still scanning...)"
        } else {
            status = "Loaded \(images.count) images, still scanning..."
        }
    }

    private var folderScanOptions: FolderScanOptions {
        FolderScanOptions(
            includeSubfolders: includeSubfolders,
            maxDepth: maxFolderDepth,
            maxImages: maxPhotoCount
        )
    }

    private func folderURL(for url: URL) -> URL {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return url
        }
        return url.deletingLastPathComponent()
    }

    private var usesDefaultViewOptions: Bool {
        sortOption == .name &&
            sortAscending &&
            typeFilter == "All" &&
            nameFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func applyViewOptions(preserving preferredURL: URL?) {
        guard !allImages.isEmpty else { return }

        let filtered = allImages.filter { url in
            let matchesType = typeFilter == "All" || normalizedType(url) == typeFilter
            let matchesName = nameFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                url.lastPathComponent.localizedCaseInsensitiveContains(nameFilter)
            return matchesType && matchesName
        }

        images = sort(filtered)
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
        warmInitialThumbnails()
        loadCurrent()
    }

    private func warmInitialThumbnails() {
        guard !images.isEmpty else { return }
        let startIndex = max(images.startIndex, currentIndex - 4)
        let endIndex = min(images.index(before: images.endIndex), currentIndex + 12)
        ThumbnailCache.shared.preheat(Array(images[startIndex...endIndex]))
    }

    private func sort(_ urls: [URL]) -> [URL] {
        urls.sorted { lhs, rhs in
            let result: ComparisonResult
            switch sortOption {
            case .name:
                result = lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent)
            case .folderPath:
                result = lhs.deletingLastPathComponent().path.localizedStandardCompare(rhs.deletingLastPathComponent().path)
            case .dateModified:
                result = modificationDate(lhs).compare(modificationDate(rhs))
            case .fileType:
                result = normalizedType(lhs).localizedStandardCompare(normalizedType(rhs))
            }

            if result == .orderedSame {
                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
            return sortAscending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private func normalizedType(_ url: URL) -> String {
        url.pathExtension.isEmpty ? "Other" : url.pathExtension.uppercased()
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}

private extension URL {
    var isGIFForViewer: Bool {
        pathExtension.caseInsensitiveCompare("gif") == .orderedSame
    }
}
