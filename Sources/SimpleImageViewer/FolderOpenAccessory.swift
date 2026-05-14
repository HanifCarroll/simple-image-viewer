import AppKit
import SwiftUI

final class FolderOpenAccessoryModel: ObservableObject {
    @Published var includeSubfolders: Bool
    @Published var maxFolderDepth: Int
    @Published var maxPhotoCount: Int
    @Published var summary: FolderScanSummary?

    init(includeSubfolders: Bool, maxFolderDepth: Int, maxPhotoCount: Int) {
        self.includeSubfolders = includeSubfolders
        self.maxFolderDepth = maxFolderDepth
        self.maxPhotoCount = maxPhotoCount
    }

    var deepestLevel: Int {
        summary?.deepestLevel ?? 0
    }

    var hasSubfolders: Bool {
        deepestLevel > 0
    }

    var includedImageCount: Int {
        guard let summary else { return 0 }
        return summary.levels
            .filter { $0.depth <= (includeSubfolders ? maxFolderDepth : 0) }
            .reduce(0) { $0 + $1.imageCount }
    }

    var cappedImageCount: Int {
        guard maxPhotoCount > 0 else { return includedImageCount }
        return min(includedImageCount, maxPhotoCount)
    }

    func updateSelection(_ url: URL?) {
        guard let url else {
            summary = nil
            includeSubfolders = false
            return
        }

        summary = scanFolder(url)
        clampOptions()
    }

    func clampOptions() {
        guard hasSubfolders else {
            includeSubfolders = false
            return
        }

        if includeSubfolders {
            maxFolderDepth = min(max(maxFolderDepth, 1), deepestLevel)
        }
    }
}

struct FolderOpenAccessoryView: View {
    @ObservedObject var model: FolderOpenAccessoryModel

    private var includeSubfoldersBinding: Binding<Bool> {
        Binding(
            get: { model.includeSubfolders },
            set: { enabled in
                model.includeSubfolders = enabled && model.hasSubfolders
                model.clampOptions()
            }
        )
    }

    private var folderDepthBinding: Binding<Int> {
        Binding(
            get: { min(max(model.maxFolderDepth, 1), max(model.deepestLevel, 1)) },
            set: { model.maxFolderDepth = min(max($0, 1), model.deepestLevel) }
        )
    }

    private var photoLimitLabel: String {
        model.maxPhotoCount <= 0 ? "No limit" : model.maxPhotoCount.formatted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            options

            if let summary = model.summary {
                summaryView(summary)
            } else {
                Text("Select a folder to preview image counts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 460)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Include subfolders", isOn: includeSubfoldersBinding)
                .disabled(!model.hasSubfolders)

            if model.summary != nil && !model.hasSubfolders {
                Text("No subfolders found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.includeSubfolders {
                controlRow(label: "Folder levels") {
                    Stepper(value: folderDepthBinding, in: 1...model.deepestLevel) {
                        Text("\(folderDepthBinding.wrappedValue)")
                            .monospacedDigit()
                            .frame(width: 72, alignment: .trailing)
                    }
                } help: {
                    Text("1-\(model.deepestLevel) available")
                }
            }

            controlRow(label: "Photo limit") {
                Stepper(value: $model.maxPhotoCount, in: 0...100_000, step: 100) {
                    Text(photoLimitLabel)
                        .monospacedDigit()
                        .frame(width: 96, alignment: .trailing)
                }
            } help: {
                Text("0 means no limit")
            }
        }
    }

    private func summaryView(_ summary: FolderScanSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(summary.totalImages.formatted()) images across \(summary.totalFolders.formatted()) folders")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.includeSubfolders {
                levelTable(summary)
            } else {
                Text("Will load \(model.cappedImageCount.formatted()) of \(model.includedImageCount.formatted()) images in the selected folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func levelTable(_ summary: FolderScanSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Level").frame(width: 54, alignment: .leading)
                Text("Folders").frame(width: 76, alignment: .trailing)
                Text("Images").frame(width: 76, alignment: .trailing)
                Text("Included").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(summary.levels) { level in
                let included = level.depth <= model.maxFolderDepth
                HStack {
                    Text("\(level.depth)").frame(width: 54, alignment: .leading)
                    Text(level.folderCount.formatted()).frame(width: 76, alignment: .trailing)
                    Text(level.imageCount.formatted()).frame(width: 76, alignment: .trailing)
                    Text(included ? "Yes" : "No")
                        .foregroundStyle(included ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(.caption, design: .monospaced))
            }

            Text("Will load \(model.cappedImageCount.formatted()) of \(model.includedImageCount.formatted()) included images.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func controlRow<Control: View, Help: View>(
        label: String,
        @ViewBuilder control: () -> Control,
        @ViewBuilder help: () -> Help
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 104, alignment: .leading)
            control()
                .frame(width: 150, alignment: .leading)
            Spacer()
            help()
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 148, alignment: .trailing)
        }
    }
}

final class FolderOpenPanelDelegate: NSObject, NSOpenSavePanelDelegate {
    private let model: FolderOpenAccessoryModel

    init(model: FolderOpenAccessoryModel) {
        self.model = model
    }

    func panelSelectionDidChange(_ sender: Any?) {
        guard let panel = sender as? NSOpenPanel else { return }
        model.updateSelection(panel.url ?? panel.directoryURL)
    }
}
