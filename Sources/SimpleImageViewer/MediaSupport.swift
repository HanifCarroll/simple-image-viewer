import AVFoundation
import Foundation

enum MediaKind: String, CaseIterable, Identifiable {
    case image = "Images"
    case video = "Videos"

    var id: Self { self }
}

enum MediaSupport {
    static let allKindsFilter = "All"

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tif", "tiff", "bmp"
    ]

    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm"
    ]

    static func kind(for url: URL) -> MediaKind? {
        let pathExtension = url.pathExtension.lowercased()
        if imageExtensions.contains(pathExtension) { return .image }
        if videoExtensions.contains(pathExtension) { return .video }
        return nil
    }

    static func isSupportedFile(_ url: URL) -> Bool {
        guard kind(for: url) != nil else { return false }
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        return values?.isRegularFile == true && values?.isSymbolicLink != true
    }

    static func durationText(for seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "" }
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3_600
        let minutes = totalSeconds % 3_600 / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension URL {
    var mediaKind: MediaKind? {
        MediaSupport.kind(for: self)
    }

    var isVideoForViewer: Bool {
        mediaKind == .video
    }

    var isGIFForViewer: Bool {
        pathExtension.caseInsensitiveCompare("gif") == .orderedSame
    }
}

final class VideoMetadataCache {
    static let shared = VideoMetadataCache()

    private let durationCache = NSCache<NSURL, NSNumber>()

    private init() {
        durationCache.countLimit = 1_000
    }

    func cachedDuration(for url: URL) -> Double? {
        durationCache.object(forKey: url as NSURL)?.doubleValue
    }

    func duration(for url: URL, completion: @escaping (Double?) -> Void) {
        if let cached = cachedDuration(for: url) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }

        Task.detached(priority: .utility) { [weak self] in
            let duration = try? await AVURLAsset(url: url).load(.duration)
            let seconds = duration?.seconds ?? 0
            if seconds.isFinite, seconds > 0 {
                self?.durationCache.setObject(NSNumber(value: seconds), forKey: url as NSURL)
            }
            DispatchQueue.main.async {
                completion(seconds.isFinite && seconds > 0 ? seconds : nil)
            }
        }
    }
}
