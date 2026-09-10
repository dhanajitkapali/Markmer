import Foundation
import AppKit
import UniformTypeIdentifiers

struct RecentFile: Identifiable, Codable, Hashable {
    var path: String
    var lastOpened: Date

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
    var folder: String {
        url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

@MainActor
final class DocumentStore: ObservableObject {
    static let shared = DocumentStore()

    @Published private(set) var recents: [RecentFile] = []
    @Published private(set) var current: URL?
    @Published private(set) var markdown: String = ""
    @Published private(set) var renderVersion: Int = 0
    @Published var errorMessage: String?
    @Published private(set) var zoom: Double = {
        let stored = UserDefaults.standard.object(forKey: "markmer.zoom") as? Double ?? 1.0
        return min(max((stored * 10).rounded() / 10, DocumentStore.zoomRange.lowerBound), DocumentStore.zoomRange.upperBound)
    }()

    static let zoomRange: ClosedRange<Double> = 0.5...3.0
    private let zoomStep = 0.1
    private let recentsKey = "markmer.recents"
    private let maxRecents = 40
    private var watcher: FileWatcher?

    static let markdownTypes: [UTType] = {
        var types: [UTType] = [.plainText, .text]
        if let md = UTType("net.daringfireball.markdown") { types.insert(md, at: 0) }
        for ext in ["md", "markdown", "mdown", "mkd"] {
            if let t = UTType(filenameExtension: ext) { types.append(t) }
        }
        return types
    }()

    private init() {
        loadRecents()
    }

    // MARK: - Opening

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown File"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.markdownTypes
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.open(url) }
        }
    }

    func open(_ url: URL) {
        let url = url.standardizedFileURL
        do {
            let text = try Self.readText(at: url)
            markdown = text
            current = url
            errorMessage = nil
            renderVersion &+= 1
            addRecent(url)
            startWatching(url)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            errorMessage = "Couldn't open \(url.lastPathComponent): \(error.localizedDescription)"
            removeRecent(path: url.path)
        }
    }

    func reload() {
        guard let url = current else { return }
        do {
            markdown = try Self.readText(at: url)
            renderVersion &+= 1
        } catch {
            errorMessage = "Couldn't reload \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    func close() {
        current = nil
        markdown = ""
        watcher = nil
    }

    func revealCurrentInFinder() {
        guard let url = current else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func readText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Zoom

    var canZoomIn: Bool { zoom < Self.zoomRange.upperBound - 0.001 }
    var canZoomOut: Bool { zoom > Self.zoomRange.lowerBound + 0.001 }

    func zoomIn() { setZoom(zoom + zoomStep) }
    func zoomOut() { setZoom(zoom - zoomStep) }
    func resetZoom() { setZoom(1.0) }

    private func setZoom(_ value: Double) {
        let clamped = min(max((value * 10).rounded() / 10, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        guard clamped != zoom else { return }
        zoom = clamped
        UserDefaults.standard.set(clamped, forKey: "markmer.zoom")
    }

    // MARK: - Live reload

    private func startWatching(_ url: URL) {
        watcher = FileWatcher(url: url) { [weak self] in
            Task { @MainActor in self?.reload() }
        }
    }

    // MARK: - Recents

    private func loadRecents() {
        guard let data = UserDefaults.standard.data(forKey: recentsKey),
              let decoded = try? JSONDecoder().decode([RecentFile].self, from: data) else { return }
        recents = decoded.sorted { $0.lastOpened > $1.lastOpened }
    }

    private func saveRecents() {
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: recentsKey)
        }
    }

    private func addRecent(_ url: URL) {
        recents.removeAll { $0.path == url.path }
        recents.insert(RecentFile(path: url.path, lastOpened: Date()), at: 0)
        if recents.count > maxRecents { recents.removeLast(recents.count - maxRecents) }
        saveRecents()
    }

    func removeRecent(path: String) {
        recents.removeAll { $0.path == path }
        saveRecents()
    }

    func clearRecents() {
        recents.removeAll()
        saveRecents()
    }
}
