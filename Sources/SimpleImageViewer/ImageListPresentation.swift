import Foundation

enum ImageSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case folderPath = "Folder"
    case dateModified = "Date Modified"
    case fileType = "File Type"

    var id: Self { self }
}

struct ImageViewOptions {
    var sortOption: ImageSortOption
    var sortAscending: Bool
    var mediaKindFilter: String
    var typeFilter: String
    var nameFilter: String

    var usesDefaultProjection: Bool {
        sortOption == .name &&
            sortAscending &&
            mediaKindFilter == MediaSupport.allKindsFilter &&
            typeFilter == ImageListPresenter.allTypesFilter &&
            nameFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum ImageListPresenter {
    static let allTypesFilter = "All"

    static func availableTypeFilters(for urls: [URL]) -> [String] {
        let extensions = Set(urls.map { normalizedType($0) })
        return [allTypesFilter] + extensions.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func availableMediaKindFilters(for urls: [URL]) -> [String] {
        let kinds = Set(urls.compactMap { $0.mediaKind?.rawValue })
        return [MediaSupport.allKindsFilter] + kinds.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func project(_ urls: [URL], using options: ImageViewOptions) -> [URL] {
        sort(filter(urls, using: options), using: options)
    }

    static func normalizedType(_ url: URL) -> String {
        url.pathExtension.isEmpty ? "Other" : url.pathExtension.uppercased()
    }

    private static func filter(_ urls: [URL], using options: ImageViewOptions) -> [URL] {
        let isNameFilterEmpty = options.nameFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return urls.filter { url in
            let matchesKind = options.mediaKindFilter == MediaSupport.allKindsFilter ||
                url.mediaKind?.rawValue == options.mediaKindFilter
            let matchesType = options.typeFilter == allTypesFilter || normalizedType(url) == options.typeFilter
            let matchesName = isNameFilterEmpty ||
                url.lastPathComponent.localizedCaseInsensitiveContains(options.nameFilter)
            return matchesKind && matchesType && matchesName
        }
    }

    private static func sort(_ urls: [URL], using options: ImageViewOptions) -> [URL] {
        urls.sorted { lhs, rhs in
            let result: ComparisonResult
            switch options.sortOption {
            case .name:
                result = lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent)
            case .folderPath:
                result = lhs.deletingLastPathComponent().path.localizedStandardCompare(rhs.deletingLastPathComponent().path)
            case .dateModified:
                result = modificationDate(lhs).compare(modificationDate(rhs))
            case .fileType:
                result = normalizedType(lhs).localizedStandardCompare(normalizedType(rhs))
            }

            if result == .orderedSame {
                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
            return options.sortAscending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
