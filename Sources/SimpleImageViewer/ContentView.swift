import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ImageStore

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            imageCanvas
            thumbnailRail
        }
        .background(.regularMaterial)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button("Open Image") { store.openImagePanel() }
            Button("Open Folder") { store.openFolderPanel() }
            Text(store.status)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.leading, 8)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var imageCanvas: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if let image = store.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            } else {
                Text(store.status)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thumbnailRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Array(store.images.enumerated()), id: \.offset) { index, url in
                    ThumbnailButton(
                        url: url,
                        selected: index == store.currentIndex,
                        action: { store.select(index) }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(height: 104)
        .background(.bar)
    }
}
