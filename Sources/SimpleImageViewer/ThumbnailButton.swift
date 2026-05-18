import AppKit
import SwiftUI

struct ThumbnailButton: View {
    let url: URL
    let selected: Bool
    let action: () -> Void
    @StateObject private var loader = ThumbnailLoader()

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.accentColor.opacity(0.22) : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 2 : 1)
                    )
                if let image = loader.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(7)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .opacity(0.45)
                }
                if url.isVideoForViewer {
                    videoBadge
                }
            }
            .frame(width: 70, height: 70)
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 78, height: 78)
        .onAppear {
            loader.load(url)
        }
        .onChange(of: url) { _, newURL in
            loader.load(newURL)
        }
        .onDisappear {
            loader.cancel()
        }
    }

    private var videoBadge: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .bold))
                Spacer(minLength: 4)
                if !loader.durationText.isEmpty {
                    Text(loader.durationText)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.62), in: Capsule())
            .padding(7)
        }
    }
}

private final class ThumbnailLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var durationText = ""

    private var loadingURL: URL?

    func load(_ url: URL) {
        if loadingURL == url, image != nil {
            return
        }

        loadingURL = url
        durationText = ""
        loadDurationIfNeeded(for: url)
        if let cached = ThumbnailCache.shared.image(for: url) {
            image = cached
            return
        }

        image = nil
        ThumbnailCache.shared.load(url) { [weak self] thumbnail in
            guard let self, self.loadingURL == url else { return }
            self.image = thumbnail
        }
    }

    func cancel() {
        loadingURL = nil
    }

    private func loadDurationIfNeeded(for url: URL) {
        guard url.isVideoForViewer else { return }
        VideoMetadataCache.shared.duration(for: url) { [weak self] seconds in
            guard let self, self.loadingURL == url else { return }
            self.durationText = seconds.map(MediaSupport.durationText(for:)) ?? ""
        }
    }
}
