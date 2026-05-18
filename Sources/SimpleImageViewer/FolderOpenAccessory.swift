import AppKit

final class FolderOpenAccessoryModel {
    var includeSubfolders: Bool
    var maxFolderDepth: Int
    var maxPhotoCount: Int
    var summary: FolderScanSummary?

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

    var selectedFolderImageCount: Int {
        summary?.levels.first(where: { $0.depth == 0 })?.imageCount ?? 0
    }

    var includedImageCount: Int {
        guard let summary else { return 0 }
        let maxDepth = includeSubfolders ? maxFolderDepth : 0
        return summary.levels
            .filter { $0.depth <= maxDepth }
            .reduce(0) { $0 + $1.imageCount }
    }

    var cappedImageCount: Int {
        guard maxPhotoCount > 0 else { return includedImageCount }
        return min(includedImageCount, maxPhotoCount)
    }

    func clearSelection() {
        summary = nil
        includeSubfolders = false
    }

    func updateSummary(_ summary: FolderScanSummary) {
        self.summary = summary
        clampOptions()
    }

    func clampOptions() {
        guard hasSubfolders else {
            includeSubfolders = false
            maxFolderDepth = 1
            return
        }

        if includeSubfolders {
            maxFolderDepth = min(max(maxFolderDepth, 1), deepestLevel)
        }
    }
}

final class FolderOpenAccessoryView: NSView {
    let model: FolderOpenAccessoryModel

    private let includeSubfoldersButton = NSButton(checkboxWithTitle: "Include subfolders", target: nil, action: nil)
    private let depthLabel = NSTextField(labelWithString: "Depth")
    private let depthValueLabel = NSTextField(labelWithString: "1")
    private let depthStepper = NSStepper()
    private let depthHelpLabel = NSTextField(labelWithString: "")
    private let photoLimitValueLabel = NSTextField(labelWithString: "No limit")
    private let photoLimitStepper = NSStepper()
    private let summaryLabel = NSTextField(wrappingLabelWithString: "Select a folder to preview media counts.")
    private let levelsLabel = NSTextField(wrappingLabelWithString: "")
    private let depthRow = NSStackView()
    private var scanGeneration = 0
    private var scanCancellation: FolderDiscoveryCancellation?

    init(model: FolderOpenAccessoryModel) {
        self.model = model
        super.init(frame: NSRect(x: 0, y: 0, width: 720, height: 160))
        buildView()
        refresh()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func updateSelection(_ url: URL?) {
        scanCancellation?.cancel()
        scanGeneration += 1
        let generation = scanGeneration
        guard let url else {
            scanCancellation = nil
            model.clearSelection()
            refresh()
            return
        }

        let cancellation = FolderDiscoveryCancellation()
        scanCancellation = cancellation
        let folderURL = Self.folderURL(for: url)
        summaryLabel.stringValue = "Scanning folder..."
        levelsLabel.stringValue = ""
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let summary = scanFolder(folderURL, cancellation: cancellation)
            DispatchQueue.main.async {
                guard let self, self.scanGeneration == generation, !summary.wasCancelled else { return }
                self.model.updateSummary(summary)
                self.refresh()
            }
        }
    }

    private static func folderURL(for url: URL) -> URL {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return url
        }
        return url.deletingLastPathComponent()
    }

    private func buildView() {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 720).isActive = true

        includeSubfoldersButton.target = self
        includeSubfoldersButton.action = #selector(includeSubfoldersChanged)

        depthStepper.target = self
        depthStepper.action = #selector(depthChanged)
        depthStepper.minValue = 1
        depthStepper.increment = 1
        depthStepper.valueWraps = false

        photoLimitStepper.target = self
        photoLimitStepper.action = #selector(photoLimitChanged)
        photoLimitStepper.minValue = 0
        photoLimitStepper.maxValue = 100_000
        photoLimitStepper.increment = 100
        photoLimitStepper.valueWraps = false

        for label in [summaryLabel, levelsLabel, depthHelpLabel] {
            label.textColor = .secondaryLabelColor
            label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        }
        levelsLabel.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

        depthValueLabel.alignment = .right
        depthValueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        depthValueLabel.widthAnchor.constraint(equalToConstant: 34).isActive = true

        photoLimitValueLabel.alignment = .right
        photoLimitValueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        photoLimitValueLabel.widthAnchor.constraint(equalToConstant: 78).isActive = true

        depthRow.orientation = .horizontal
        depthRow.alignment = .centerY
        depthRow.spacing = 8
        depthRow.addArrangedSubview(depthLabel)
        depthRow.addArrangedSubview(depthValueLabel)
        depthRow.addArrangedSubview(depthStepper)
        depthRow.addArrangedSubview(depthHelpLabel)

        let photoRow = NSStackView()
        photoRow.orientation = .horizontal
        photoRow.alignment = .centerY
        photoRow.spacing = 8
        photoRow.addArrangedSubview(NSTextField(labelWithString: "Photo limit"))
        photoRow.addArrangedSubview(photoLimitValueLabel)
        photoRow.addArrangedSubview(photoLimitStepper)

        let controlsRow = NSStackView()
        controlsRow.orientation = .horizontal
        controlsRow.alignment = .centerY
        controlsRow.spacing = 24
        controlsRow.addArrangedSubview(includeSubfoldersButton)
        controlsRow.addArrangedSubview(depthRow)
        controlsRow.addArrangedSubview(photoRow)

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(controlsRow)
        root.addArrangedSubview(summaryLabel)
        root.addArrangedSubview(levelsLabel)
        addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            root.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    private func refresh() {
        includeSubfoldersButton.state = model.includeSubfolders ? .on : .off
        includeSubfoldersButton.isEnabled = model.hasSubfolders

        depthStepper.maxValue = Double(max(model.deepestLevel, 1))
        depthStepper.integerValue = min(max(model.maxFolderDepth, 1), max(model.deepestLevel, 1))
        depthValueLabel.stringValue = "\(depthStepper.integerValue)"
        depthHelpLabel.stringValue = "1-\(max(model.deepestLevel, 1))"
        depthRow.isHidden = !model.includeSubfolders

        photoLimitStepper.integerValue = model.maxPhotoCount
        photoLimitValueLabel.stringValue = model.maxPhotoCount <= 0 ? "No limit" : model.maxPhotoCount.formatted()

        guard let summary = model.summary else {
            summaryLabel.stringValue = "Select a folder to preview media counts."
            levelsLabel.stringValue = ""
            return
        }

        if model.includeSubfolders {
            summaryLabel.stringValue = "Will load \(model.cappedImageCount.formatted()) of \(model.includedImageCount.formatted()) included media files."
            levelsLabel.stringValue = levelTableText(for: summary)
        } else {
            summaryLabel.stringValue = "\(model.selectedFolderImageCount.formatted()) media files in selected folder."
            levelsLabel.stringValue = ""
        }
    }

    @objc private func includeSubfoldersChanged() {
        model.includeSubfolders = includeSubfoldersButton.state == .on && model.hasSubfolders
        model.clampOptions()
        refresh()
    }

    @objc private func depthChanged() {
        model.maxFolderDepth = depthStepper.integerValue
        model.clampOptions()
        refresh()
    }

    @objc private func photoLimitChanged() {
        model.maxPhotoCount = photoLimitStepper.integerValue
        refresh()
    }

    private func levelTableText(for summary: FolderScanSummary) -> String {
        let rows = summary.levels.map { level in
            let load = level.depth <= model.maxFolderDepth ? "yes" : "no"
            return String(
                format: "%5d  %8@  %8@  %@",
                level.depth,
                level.imageCount.formatted(),
                level.folderCount.formatted(),
                load
            )
        }
        return (["Level     Media   Folders  Load"] + rows).joined(separator: "\n")
    }
}

final class FolderOpenPanelDelegate: NSObject, NSOpenSavePanelDelegate {
    private let accessoryView: FolderOpenAccessoryView

    init(accessoryView: FolderOpenAccessoryView) {
        self.accessoryView = accessoryView
    }

    func panelSelectionDidChange(_ sender: Any?) {
        guard let panel = sender as? NSOpenPanel else { return }
        accessoryView.updateSelection(panel.url ?? panel.directoryURL)
    }
}
