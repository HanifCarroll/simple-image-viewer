import AppKit
import SwiftUI

@main
struct SimpleImageViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Simple Image Viewer") {
            ViewerRootView(
                appDelegate: appDelegate
            )
        }
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Viewer") { appDelegate.openNewViewerWindow() }
                    .keyboardShortcut("n", modifiers: [.command])
                Button("Open...") { appDelegate.openActiveWindowPanel() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Open in New Viewer...") { appDelegate.openPanelInNewWindow() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandMenu("Navigate") {
                Button("Previous Image") { appDelegate.navigateActiveWindow(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Image") { appDelegate.navigateActiveWindow(1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Divider()
                Button("First Image") { appDelegate.selectFirstInActiveWindow() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("Last Image") {
                    appDelegate.selectLastInActiveWindow()
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
