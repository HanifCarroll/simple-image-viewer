import AppKit
import SwiftUI

@main
struct SimpleImageViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
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
