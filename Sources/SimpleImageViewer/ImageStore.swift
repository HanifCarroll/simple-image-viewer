import AppKit
import UniformTypeIdentifiers

final class ImageStore: ObservableObject {
    @Published var images: [URL] = []
    @Published var currentIndex = 0
    @Published var currentImage: NSImage?
    @Published var status = "Open an image or folder"

    var currentURL: URL? {
        images.indices.contains(currentIndex) ? images[currentIndex] : nil
    }

    func open(_ url: URL) {
        let folderURL: URL
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            folderURL = url
        } else {
            folderURL = url.deletingLastPathComponent()
        }

        let urls = imageURLs(in: folderURL)
        guard !urls.isEmpty else {
            images = []
            currentIndex = 0
            currentImage = nil
            status = "No supported images found"
            return
        }

        images = urls
        if !url.hasDirectoryPath,
           let index = urls.firstIndex(where: { $0.standardizedFileURL == url.standardizedFileURL }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        loadCurrent()
    }

    func openImagePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Open Folder"
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
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

    private func loadCurrent() {
        guard let currentURL else { return }
        currentImage = NSImage(contentsOf: currentURL)
        status = "\(currentURL.lastPathComponent)  (\(currentIndex + 1) of \(images.count))"
    }
}
