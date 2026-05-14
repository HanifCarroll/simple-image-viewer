import SwiftUI

private struct ActiveImageStoreKey: FocusedValueKey {
    typealias Value = ImageStore
}

extension FocusedValues {
    var activeImageStore: ImageStore? {
        get { self[ActiveImageStoreKey.self] }
        set { self[ActiveImageStoreKey.self] = newValue }
    }
}
