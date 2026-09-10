import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var searchText = ""
    @State private var isDropTargeted = false

    var body: some View {
        NavigationSplitView {
            SidebarView(searchText: $searchText)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 380)
        } detail: {
            DetailView()
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Filter recent files")
        .navigationTitle(store.current?.lastPathComponent ?? "Markmer")
        .navigationSubtitle(store.current.map { shortFolder($0) } ?? "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ControlGroup {
                    Button {
                        store.zoomOut()
                    } label: {
                        Label("Zoom Out", systemImage: "minus")
                    }
                    .help("Zoom out (⌘-)")
                    .disabled(!store.canZoomOut)

                    Button {
                        store.resetZoom()
                    } label: {
                        Text(store.zoom, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .frame(minWidth: 44)
                    }
                    .help("Reset to actual size (⌘0)")

                    Button {
                        store.zoomIn()
                    } label: {
                        Label("Zoom In", systemImage: "plus")
                    }
                    .help("Zoom in (⌘=)")
                    .disabled(!store.canZoomIn)
                }
                .disabled(store.current == nil)

                Button {
                    store.reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .help("Reload (⌘R)")
                .disabled(store.current == nil)

                Button {
                    store.revealCurrentInFinder()
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .help("Reveal in Finder (⇧⌘R)")
                .disabled(store.current == nil)

                Button {
                    store.presentOpenPanel()
                } label: {
                    Label("Open", systemImage: "doc.badge.plus")
                }
                .help("Open a Markdown file (⌘O)")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .alert("Markmer", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func shortFolder(_ url: URL) -> String {
        url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let u = item as? URL {
                url = u
            }
            guard let url else { return }
            Task { @MainActor in store.open(url) }
        }
        return true
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject private var store: DocumentStore
    @Binding var searchText: String

    private var filtered: [RecentFile] {
        guard !searchText.isEmpty else { return store.recents }
        return store.recents.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.folder.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selection: Binding<String?> {
        Binding(
            get: { store.current?.path },
            set: { path in
                guard let path, path != store.current?.path else { return }
                store.open(URL(fileURLWithPath: path))
            }
        )
    }

    var body: some View {
        List(selection: selection) {
            Section("Recent") {
                if filtered.isEmpty {
                    Text(searchText.isEmpty ? "Files you open will appear here." : "No matches.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(filtered) { recent in
                        RecentRow(recent: recent)
                            .tag(recent.path)
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([recent.url])
                                }
                                Button("Copy Path") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(recent.path, forType: .string)
                                }
                                Divider()
                                Button("Remove from Recents", role: .destructive) {
                                    store.removeRecent(path: recent.path)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            if !store.recents.isEmpty {
                HStack {
                    Text("\(store.recents.count) file\(store.recents.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { store.clearRecents() }
                        .buttonStyle(.link)
                }
                .font(.caption)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
    }
}

struct RecentRow: View {
    let recent: RecentFile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: recent.exists ? "doc.text" : "doc.questionmark")
                .font(.title3)
                .foregroundStyle(recent.exists ? Color.accentColor : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(recent.name)
                    .lineLimit(1)
                    .foregroundStyle(recent.exists ? .primary : .secondary)
                HStack(spacing: 4) {
                    Text(recent.folder)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Text("·")
                    Text(recent.lastOpened, format: .relative(presentation: .named))
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .help(recent.path)
    }
}

// MARK: - Detail

struct DetailView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        if let url = store.current {
            MarkdownWebView(
                markdown: store.markdown,
                baseURL: url.deletingLastPathComponent(),
                version: store.renderVersion,
                zoom: store.zoom
            )
            .id("webview")
        } else {
            EmptyStateView()
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            VStack(spacing: 6) {
                Text("Markmer")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Markdown, with Mermaid diagrams that just render.")
                    .foregroundStyle(.secondary)
            }
            Button {
                store.presentOpenPanel()
            } label: {
                Label("Open Markdown File…", systemImage: "folder")
                    .padding(.horizontal, 6)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            Text("or drop a .md file anywhere in this window")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
