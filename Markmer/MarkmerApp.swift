import SwiftUI
import AppKit

@main
struct MarkmerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DocumentStore.shared

    var body: some Scene {
        Window("Markmer", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 760, minHeight: 480)
        }
        .defaultSize(width: 1180, height: 780)
        .windowToolbarStyle(.unified)
        .commands {
            MarkmerCommands(store: store)
        }
    }
}

/// Receives file-open requests from Finder / the Dock and forwards them to the store.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        DocumentStore.shared.open(url)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

struct MarkmerCommands: Commands {
    @ObservedObject var store: DocumentStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") { store.presentOpenPanel() }
                .keyboardShortcut("o", modifiers: .command)

            Menu("Open Recent") {
                if store.recents.isEmpty {
                    Text("No Recent Files")
                } else {
                    ForEach(store.recents) { recent in
                        Button(recent.name) { store.open(recent.url) }
                    }
                    Divider()
                    Button("Clear Menu") { store.clearRecents() }
                }
            }

            Divider()

            Button("Reveal in Finder") { store.revealCurrentInFinder() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.current == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Reload") { store.reload() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.current == nil)

            Divider()

            Button("Zoom In") { store.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(!store.canZoomIn)
            Button("Zoom Out") { store.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!store.canZoomOut)
            Button("Actual Size") { store.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(store.zoom == 1.0)
        }
    }
}
