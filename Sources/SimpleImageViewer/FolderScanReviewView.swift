import SwiftUI

struct FolderScanReviewView: View {
    @ObservedObject var store: ImageStore
    let summary: FolderScanSummary

    private var hasSubfolders: Bool {
        summary.deepestLevel > 0
    }

    private var includeSubfoldersBinding: Binding<Bool> {
        Binding(
            get: { store.includeSubfolders },
            set: { enabled in
                store.includeSubfolders = enabled && hasSubfolders
                if store.includeSubfolders {
                    store.maxFolderDepth = min(max(store.maxFolderDepth, 1), summary.deepestLevel)
                }
            }
        )
    }

    private var folderDepthBinding: Binding<Int> {
        Binding(
            get: { min(max(store.maxFolderDepth, 1), summary.deepestLevel) },
            set: { store.maxFolderDepth = min(max($0, 1), summary.deepestLevel) }
        )
    }

    private var effectiveLimitDescription: String {
        if store.maxPhotoCount <= 0 {
            return "No limit"
        }
        return store.maxPhotoCount.formatted()
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
        .onAppear(perform: clampScanOptions)
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
            Toggle("Include subfolders", isOn: includeSubfoldersBinding)
                .disabled(!hasSubfolders)

            if !hasSubfolders {
                Text("No subfolders found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.includeSubfolders {
                controlRow(label: "Folder levels") {
                    Stepper(value: folderDepthBinding, in: 1...summary.deepestLevel) {
                        Text("\(folderDepthBinding.wrappedValue)")
                            .monospacedDigit()
                            .frame(width: 72, alignment: .trailing)
                    }
                } help: {
                    Text("1-\(summary.deepestLevel) available")
                }
            }

            controlRow(label: "Photo limit") {
                Stepper(value: $store.maxPhotoCount, in: 0...100_000, step: 100) {
                    Text(effectiveLimitDescription)
                        .monospacedDigit()
                        .frame(width: 96, alignment: .trailing)
                }
            } help: {
                Text("0 means no limit")
            }
        }
    }

    private func controlRow<Control: View, Help: View>(
        label: String,
        @ViewBuilder control: () -> Control,
        @ViewBuilder help: () -> Help
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 110, alignment: .leading)
            control()
                .frame(width: 150, alignment: .leading)
            Spacer()
            help()
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 170, alignment: .trailing)
        }
    }

    private var levelTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.includeSubfolders {
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
                    let included = level.depth <= store.maxFolderDepth
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
            } else {
                Text("\(summary.levels.first?.imageCount ?? 0) images in the selected folder.")
                    .foregroundStyle(.secondary)
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

    private func clampScanOptions() {
        guard hasSubfolders else {
            store.includeSubfolders = false
            return
        }

        if store.includeSubfolders {
            store.maxFolderDepth = min(max(store.maxFolderDepth, 1), summary.deepestLevel)
        }
    }
}
