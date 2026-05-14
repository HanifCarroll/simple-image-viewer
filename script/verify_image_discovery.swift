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

        let summary = scanFolder(fixtureFolder)
        guard summary.totalImages == expectedNames.count else {
            fail("expected \(expectedNames.count) images in scan summary, got \(summary.totalImages)")
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

        print("Verified image discovery and NSImage decoding with \(expectedNames.count) fixture images")
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("verify-image-discovery: \(message)\n".utf8))
        exit(1)
    }
}
