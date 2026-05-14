import AppKit
import SwiftUI

@main
struct SimpleImageViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ImageStore()
    @FocusedValue(\.activeImageStore) private var activeImageStore
    @State private var handledLaunchArgument = false

    var body: some Scene {
        WindowGroup("Simple Image Viewer") {
            ContentView(store: store)
                .frame(minWidth: 760, idealWidth: 1100, minHeight: 520, idealHeight: 760)
                .onAppear {
                    appDelegate.attach(store)
                    if !handledLaunchArgument,
                       let path = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) {
                        handledLaunchArgument = true
                        store.open(URL(fileURLWithPath: path))
                    }
                }
        }
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") { activeImageStore?.openPanel() ?? store.openPanel() }
                    .keyboardShortcut("o", modifiers: [.command])
            }
            CommandMenu("Navigate") {
                Button("First Image") { activeImageStore?.select(0) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("Last Image") {
                    if let activeImageStore {
                        activeImageStore.select(activeImageStore.images.count - 1)
                    }
                }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
            }
        }
    }
}
