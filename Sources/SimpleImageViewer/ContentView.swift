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
            if !store.allImages.isEmpty {
                viewerOptions
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var viewerOptions: some View {
        HStack(spacing: 8) {
            Picker("Sort", selection: $store.sortOption) {
                ForEach(ImageSortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            Button(store.sortAscending ? "A-Z" : "Z-A") {
                store.toggleSortDirection()
            }
            .frame(width: 54)

            Picker("Type", selection: $store.typeFilter) {
                ForEach(store.availableTypeFilters, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .labelsHidden()
            .frame(width: 90)

            TextField("Filter", text: $store.nameFilter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)

            if !store.nameFilter.isEmpty {
                Button("Clear") { store.clearNameFilter() }
            }
        }
    }

    private var imageCanvas: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if let url = store.currentURL, url.isGIF {
                AnimatedImageView(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            } else if let image = store.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            } else {
                Text(store.status)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
        .clipped()
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
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .frame(height: 112)
        .fixedSize(horizontal: false, vertical: true)
        .background(.bar)
    }
}

private extension URL {
    var isGIF: Bool {
        pathExtension.caseInsensitiveCompare("gif") == .orderedSame
    }
}
