import AppKit
import Darwin
import Foundation

@main
struct VerifyImageDiscovery {
    static func main() {
        guard CommandLine.arguments.count == 2 else {
            fail("usage: verify-image-discovery <fixture-folder>")
        }

        let fixtureFolder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let urls = imageURLs(in: fixtureFolder)
        let names = urls.map(\.lastPathComponent)
        let expectedNames = ["image-02.png", "image-10.jpg"]

        guard names == expectedNames else {
            fail("expected image discovery order \(expectedNames), got \(names)")
        }

        guard let image = NSImage(contentsOf: urls[0]),
              image.size.width > 0,
              image.size.height > 0 else {
            fail("fixture image did not decode with NSImage: \(urls[0].path)")
        }

        let recursiveOptions = FolderScanOptions(includeSubfolders: true, maxDepth: 1, maxImages: 0)
        let recursiveURLs = imageURLs(in: fixtureFolder, options: recursiveOptions)
        let recursiveNames = relativeNames(for: recursiveURLs, from: fixtureFolder)
        let expectedRecursiveNames = ["image-02.png", "image-10.jpg", "nested/image-03.png"]
        guard recursiveNames == expectedRecursiveNames else {
            fail("expected recursive image discovery order \(expectedRecursiveNames), got \(recursiveNames)")
        }

        let summary = scanFolder(fixtureFolder)
        guard summary.totalImages == expectedRecursiveNames.count else {
            fail("expected \(expectedRecursiveNames.count) images in scan summary, got \(summary.totalImages)")
        }
        guard summary.totalFolders == 2, summary.deepestLevel == 1 else {
            fail("expected scan summary to include root and nested folder, got folders=\(summary.totalFolders), deepestLevel=\(summary.deepestLevel)")
        }
        guard summary.isImageIndexComplete, !summary.wasCancelled else {
            fail("expected complete, non-cancelled scan summary")
        }

        let limitedRecursiveURLs = imageURLs(
            in: summary,
            options: FolderScanOptions(includeSubfolders: true, maxDepth: 1, maxImages: 2)
        )
        let limitedRecursiveNames = relativeNames(for: limitedRecursiveURLs, from: fixtureFolder)
        guard limitedRecursiveNames == expectedNames else {
            fail("expected max image projection \(expectedNames), got \(limitedRecursiveNames)")
        }

        var batches: [[URL]] = []
        var sawFinished = false
        enumerateImageURLBatches(in: fixtureFolder, batchSize: 1) { batch, finished in
            batches.append(batch)
            sawFinished = finished
        }

        let batchedNames = batches.flatMap { $0.map(\.lastPathComponent) }
        guard batchedNames == expectedNames, sawFinished else {
            fail("expected batched discovery \(expectedNames) and finished=true, got \(batchedNames), finished=\(sawFinished)")
        }

        verifyOpeningPlan(for: urls[0], fixtureFolder: fixtureFolder, options: recursiveOptions)
        verifyListProjection(recursiveURLs, fixtureFolder: fixtureFolder)

        print("Verified image discovery, opening plans, list projection, and NSImage decoding with \(expectedRecursiveNames.count) fixture images")
    }

    private static func verifyOpeningPlan(for imageURL: URL, fixtureFolder: URL, options: FolderScanOptions) {
        guard ImageOpeningService.folderURL(for: imageURL).standardizedFileURL == fixtureFolder.standardizedFileURL else {
            fail("expected image opening service to resolve image parent folder")
        }
        guard ImageOpeningService.folderURL(for: fixtureFolder).standardizedFileURL == fixtureFolder.standardizedFileURL else {
            fail("expected image opening service to preserve folder URL")
        }

        let cancellation = FolderDiscoveryCancellation()
        let plan = ImageOpeningService.plan(for: imageURL, options: options, cancellation: cancellation)
        guard plan.sourceURL.standardizedFileURL == imageURL.standardizedFileURL,
              plan.folderURL.standardizedFileURL == fixtureFolder.standardizedFileURL,
              plan.scanOptions.effectiveMaxDepth == options.effectiveMaxDepth,
              plan.cancellation === cancellation else {
            fail("image opening service returned an invalid open plan")
        }
    }

    private static func verifyListProjection(_ urls: [URL], fixtureFolder: URL) {
        let pngOptions = ImageViewOptions(
            sortOption: .name,
            sortAscending: true,
            typeFilter: "PNG",
            nameFilter: "image-03"
        )
        let pngNames = relativeNames(for: ImageListPresenter.project(urls, using: pngOptions), from: fixtureFolder)
        guard pngNames == ["nested/image-03.png"] else {
            fail("expected filtered PNG projection to select nested image, got \(pngNames)")
        }

        let typeFilters = ImageListPresenter.availableTypeFilters(for: urls)
        guard typeFilters == ["All", "JPG", "PNG"] else {
            fail("expected type filters [All, JPG, PNG], got \(typeFilters)")
        }
    }

    private static func relativeNames(for urls: [URL], from rootURL: URL) -> [String] {
        let rootPath = rootURL.standardizedFileURL.path
        return urls.map { url in
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
            return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("verify-image-discovery: \(message)\n".utf8))
        exit(1)
    }
}
