import SwiftUI
import WebKit

/// Hosts a WKWebView that renders Markdown (marked.js) with Mermaid diagrams
/// and syntax highlighting. The page is reloaded only when the document's
/// folder changes (so relative images/links resolve); edits to the same file
/// are pushed via JavaScript and preserve the scroll position.
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let baseURL: URL
    let version: Int
    let zoom: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "markmer")
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        webView.pageZoom = zoom
        context.coordinator.webView = webView
        context.coordinator.update(markdown: markdown, baseURL: baseURL, version: version)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.pageZoom != zoom { webView.pageZoom = zoom }
        context.coordinator.update(markdown: markdown, baseURL: baseURL, version: version)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "markmer")
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?

        private var loadedBaseURL: URL?
        private var lastMarkdown: String?
        private var lastVersion: Int?
        private var pageReady = false
        private var pendingMarkdown: String?

        func update(markdown: String, baseURL: URL, version: Int) {
            if loadedBaseURL != baseURL {
                loadedBaseURL = baseURL
                lastMarkdown = markdown
                lastVersion = version
                pageReady = false
                pendingMarkdown = nil
                loadPage(initialMarkdown: markdown, baseURL: baseURL)
                return
            }
            guard markdown != lastMarkdown || version != lastVersion else { return }
            lastMarkdown = markdown
            lastVersion = version
            if pageReady {
                push(markdown: markdown)
            } else {
                pendingMarkdown = markdown
            }
        }

        private func loadPage(initialMarkdown: String, baseURL: URL) {
            let html = TemplateBuilder.shared.page(initialMarkdown: initialMarkdown)
            webView?.loadHTMLString(html, baseURL: baseURL)
        }

        private func push(markdown: String) {
            guard let json = TemplateBuilder.jsonString(markdown) else { return }
            webView?.evaluateJavaScript("window.markmer && window.markmer.render(\(json));") { _, error in
                if let error { NSLog("Markmer render error: \(error.localizedDescription)") }
            }
        }

        // WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "ready":
                pageReady = true
                if let pending = pendingMarkdown {
                    pendingMarkdown = nil
                    push(markdown: pending)
                }
            case "rendered":
                NSLog("Markmer rendered: keepScroll=\(body["keepScroll"] ?? "-") savedY=\(body["savedY"] ?? "-") scrollY=\(body["scrollY"] ?? "-") height=\(body["height"] ?? "-")")
            case "log":
                NSLog("Markmer[js]: \(body["message"] ?? "")")
            default:
                break
            }
        }

        // WKNavigationDelegate
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // In-page anchors stay in the web view.
            if url.isFileURL, url.fragment != nil,
               url.deletingFragment() == webView.url?.deletingFragment() {
                decisionHandler(.allow)
                return
            }

            if url.isFileURL {
                let ext = url.pathExtension.lowercased()
                if ["md", "markdown", "mdown", "mkd", "mkdn", "mdwn", "txt", ""].contains(ext),
                   FileManager.default.fileExists(atPath: url.path) {
                    Task { @MainActor in DocumentStore.shared.open(url) }
                } else {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }

            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }
}

private extension URL {
    func deletingFragment() -> URL {
        var comps = URLComponents(url: self, resolvingAgainstBaseURL: false)
        comps?.fragment = nil
        return comps?.url ?? self
    }
}

/// Assembles the HTML page from Template.html. If vendored copies of the JS/CSS
/// libraries exist in the bundle (Resources/vendor), they are inlined so the
/// app works fully offline; otherwise the libraries load from jsDelivr.
final class TemplateBuilder {
    static let shared = TemplateBuilder()

    private let template: String
    private let assets: String

    private init() {
        let url = Bundle.main.url(forResource: "Template", withExtension: "html")
        template = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "<html><body><pre id=\"content\">Template.html missing</pre></body></html>"
        assets = TemplateBuilder.buildAssets()
    }

    func page(initialMarkdown: String) -> String {
        let json = TemplateBuilder.jsonString(initialMarkdown) ?? "\"\""
        return template
            .replacingOccurrences(of: "<!--MARKMER_ASSETS-->", with: assets)
            .replacingOccurrences(of: "<!--MARKMER_INITIAL-->", with: json)
    }

    static func jsonString(_ s: String) -> String? {
        guard let data = try? JSONEncoder().encode(s), var json = String(data: data, encoding: .utf8) else { return nil }
        // Keep the payload safe inside an inline <script>.
        json = json.replacingOccurrences(of: "</", with: "<\\/")
        json = json.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        json = json.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return json
    }

    private static func buildAssets() -> String {
        // Vendored libraries are copied flat into Contents/Resources by Xcode.
        let files = ["marked.min.js", "mermaid.min.js", "highlight.min.js", "github.min.css", "github-dark.min.css"]
        let candidates = [Bundle.main.resourceURL, Bundle.main.resourceURL?.appendingPathComponent("vendor")].compactMap { $0 }
        let vendorDir = candidates.first { dir in
            files.allSatisfy { FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path) }
        }

        if let vendorDir,
           let marked = try? String(contentsOf: vendorDir.appendingPathComponent("marked.min.js"), encoding: .utf8),
           let mermaid = try? String(contentsOf: vendorDir.appendingPathComponent("mermaid.min.js"), encoding: .utf8),
           let hljs = try? String(contentsOf: vendorDir.appendingPathComponent("highlight.min.js"), encoding: .utf8),
           let light = try? String(contentsOf: vendorDir.appendingPathComponent("github.min.css"), encoding: .utf8),
           let dark = try? String(contentsOf: vendorDir.appendingPathComponent("github-dark.min.css"), encoding: .utf8) {
            func script(_ s: String) -> String {
                "<script>\n" + s.replacingOccurrences(of: "</script", with: "<\\/script") + "\n</script>"
            }
            return """
            <style media="(prefers-color-scheme: light)">\(light)</style>
            <style media="(prefers-color-scheme: dark)">\(dark)</style>
            \(script(marked))
            \(script(hljs))
            \(script(mermaid))
            <script>window.__markmerOffline = true;</script>
            """
        }

        return """
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/styles/github.min.css" media="(prefers-color-scheme: light)">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
        <script src="https://cdn.jsdelivr.net/npm/marked@12/marked.min.js" onerror="window.__markmerScriptFailed('marked')"></script>
        <script src="https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/highlight.min.js" onerror="window.__markmerScriptFailed('highlight.js')"></script>
        <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js" onerror="window.__markmerScriptFailed('mermaid')"></script>
        """
    }
}
