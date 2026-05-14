import SwiftUI

struct FolderScanReviewView: View {
    @ObservedObject var store: ImageStore
    let summary: FolderScanSummary

    private var effectiveLimitDescription: String {
        if store.maxPhotoCount <= 0 {
            return "No photo limit"
        }
        return "Load up to \(store.maxPhotoCount.formatted()) photos"
    }

    private var includedImageCount: Int {
        summary.levels
            .filter { $0.depth <= (store.includeSubfolders ? store.maxFolderDepth : 0) }
            .reduce(0) { $0 + $1.imageCount }
    }

    private var cappedImageCount: Int {
        guard store.maxPhotoCount > 0 else { return includedImageCount }
        return min(includedImageCount, store.maxPhotoCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            options
            levelTable
            footer
        }
        .padding(20)
        .frame(width: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.rootURL.lastPathComponent)
                .font(.headline)
                .lineLimit(1)
            Text("\(summary.totalImages.formatted()) images across \(summary.totalFolders.formatted()) folders, deepest level \(summary.deepestLevel)")
                .foregroundStyle(.secondary)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Include subfolders", isOn: $store.includeSubfolders)

            HStack {
                Stepper("Folder levels: \(store.includeSubfolders ? store.maxFolderDepth : 0)", value: $store.maxFolderDepth, in: 0...50)
                    .disabled(!store.includeSubfolders)
                Spacer()
                Text("0 = selected folder only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Stepper(effectiveLimitDescription, value: $store.maxPhotoCount, in: 0...100_000, step: 100)
                Spacer()
                Text("0 = unlimited")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var levelTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Level").frame(width: 70, alignment: .leading)
                Text("Folders").frame(width: 90, alignment: .trailing)
                Text("Images").frame(width: 90, alignment: .trailing)
                Text("Included").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()

            ForEach(summary.levels) { level in
                let included = level.depth <= (store.includeSubfolders ? store.maxFolderDepth : 0)
                HStack {
                    Text("\(level.depth)").frame(width: 70, alignment: .leading)
                    Text(level.folderCount.formatted()).frame(width: 90, alignment: .trailing)
                    Text(level.imageCount.formatted()).frame(width: 90, alignment: .trailing)
                    Text(included ? "Yes" : "No")
                        .foregroundStyle(included ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(.body, design: .monospaced))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack {
            Text("Will load \(cappedImageCount.formatted()) of \(includedImageCount.formatted()) included images.")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { store.cancelPendingFolderOpen() }
                .keyboardShortcut(.cancelAction)
            Button("Open") { store.confirmPendingFolderOpen() }
                .keyboardShortcut(.defaultAction)
                .disabled(cappedImageCount == 0)
        }
    }
}
