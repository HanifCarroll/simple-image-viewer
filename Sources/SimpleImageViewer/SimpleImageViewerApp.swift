import AppKit
import SwiftUI

@main
struct SimpleImageViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ImageStore()

    var body: some Scene {
        WindowGroup("Simple Image Viewer") {
            ContentView(store: store)
                .frame(minWidth: 760, minHeight: 520)
                .onAppear {
                    appDelegate.attach(store)
                    if let path = CommandLine.arguments.dropFirst().first {
                        store.open(URL(fileURLWithPath: path))
                    }
                }
        }
        .commands {
            CommandMenu("Navigate") {
                Button("Previous Image") { store.navigate(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Image") { store.navigate(1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Divider()
                Button("First Image") { store.select(0) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("Last Image") { store.select(store.images.count - 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
            }
        }
    }
}
