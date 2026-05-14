import AppKit
import SwiftUI

@main
struct SimpleImageViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @FocusedValue(\.activeImageStore) private var activeImageStore

    var body: some Scene {
        WindowGroup("Simple Image Viewer") {
            ViewerRootView(
                appDelegate: appDelegate
            )
        }
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") { activeImageStore?.openPanel() ?? ActiveViewerStore.shared.store?.openPanel() ?? appDelegate.openPanelInNewWindow() }
                    .keyboardShortcut("o", modifiers: [.command])
            }
            CommandMenu("Navigate") {
                Button("Previous Image") { activeImageStore?.navigate(-1) ?? appDelegate.navigateActiveWindow(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Image") { activeImageStore?.navigate(1) ?? appDelegate.navigateActiveWindow(1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Divider()
                Button("First Image") { activeImageStore?.select(0) ?? appDelegate.selectFirstInActiveWindow() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("Last Image") {
                    if let activeImageStore {
                        activeImageStore.select(activeImageStore.images.count - 1)
                    } else {
                        appDelegate.selectLastInActiveWindow()
                    }
                }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
            }
        }
    }
}

private struct ViewerRootView: View {
    let appDelegate: AppDelegate
    @StateObject private var store = ImageStore()
    @State private var didAppear = false

    var body: some View {
        ContentView(store: store)
            .frame(minWidth: 760, idealWidth: 1100, minHeight: 520, idealHeight: 760)
            .onAppear {
                guard !didAppear else { return }
                didAppear = true
                appDelegate.attach(store)
            }
    }
}
