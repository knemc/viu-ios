import Combine
import Foundation
import WebKit

enum CatalogueKind: String, CaseIterable, Identifiable {
    case movies, series
    var id: Self { self }
    var title: String { self == .movies ? "Movies" : "TV Series" }
    var path: String { self == .movies ? "/movies.php" : "/tv.php" }
    var type: String { self == .movies ? "movie" : "serie" }
}

private struct BrowseSnapshot: Decodable {
    let items: [CatalogueItem]
    let ready: Bool
}

@MainActor
final class BrowseStore: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var items: [CatalogueItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var needsSignIn = false
    @Published private(set) var error: String?
    @Published private(set) var page = 1
    @Published private(set) var canLoadMore = false
    let webView: WKWebView
    private var readTask: Task<Void, Never>?
    private var generation = UUID()
    private var pendingPage = 1
    private var kind: CatalogueKind = .movies
    private var query = ""

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = AppSession.websiteDataStore
        config.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
    }

    func search(kind: CatalogueKind, query: String) {
        self.kind = kind
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        items = []
        hasLoaded = false
        page = 1
        canLoadMore = false
        request(page: 1)
    }

    func retry() {
        if pendingPage > 1, !items.isEmpty { loadMore() }
        else { request(page: 1) }
    }
    func loadMore() {
        guard !isLoading, canLoadMore else { return }
        readTask?.cancel()
        generation = UUID()
        let requestID = generation
        pendingPage = page + 1
        isLoading = true
        error = nil
        readTask = Task { [weak self] in
            guard let self else { return }
            do {
                // VIU initialises URL page parameters back to one. Its actual
                // pagination is driven by the existing page's scroll handler.
                _ = try await self.webView.evaluateJavaScript("""
                window.scrollTo(0, 0);
                requestAnimationFrame(() => window.scrollTo(0, document.documentElement.scrollHeight));
                true;
                """)
                guard !Task.isCancelled, self.generation == requestID else { return }
                await self.readCatalogue(requestID: requestID, append: true)
            } catch {
                guard !Task.isCancelled, self.generation == requestID else { return }
                self.fail("Couldn't load more titles. Please retry.")
            }
        }
    }

    func cancel() {
        generation = UUID()
        readTask?.cancel()
        webView.stopLoading()
        isLoading = false
    }

    private func request(page: Int) {
        cancel()
        pendingPage = page
        error = nil
        isLoading = true
        var components = URLComponents(string: "https://viu.to")!
        components.path = kind.path
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "abc", value: "All"),
            URLQueryItem(name: "genres", value: ""),
            URLQueryItem(name: "sortby", value: "New Arrivals"),
            URLQueryItem(name: "quality", value: "All"),
            URLQueryItem(name: "type", value: kind.type),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "token", value: ""),
            URLQueryItem(name: "ptype", value: "is")
        ]
        webView.load(URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView.url?.host == "viu.to" else { fail("VIU opened an unexpected page."); return }
        if webView.url?.path == "/login" {
            needsSignIn = true
            isLoading = false
            items = []
            return
        }
        needsSignIn = false
        guard webView.url?.path == kind.path else { fail("Return to browsing and retry."); return }
        readTask?.cancel()
        let requestID = generation
        readTask = Task { [weak self] in
            guard let self else { return }
            await self.readCatalogue(requestID: requestID, append: false)
        }
    }

    private func readCatalogue(requestID: UUID, append: Bool) async {
        guard let resource = Bundle.main.url(forResource: "Browse", withExtension: "js"),
              let script = try? String(contentsOf: resource, encoding: .utf8) else {
            self.fail("The browse reader is missing from this build."); return
        }
        var lastSignature: String?
        for _ in 0..<40 {
            guard !Task.isCancelled, self.generation == requestID else { return }
            do {
                let result = try await self.webView.evaluateJavaScript(script)
                guard !Task.isCancelled, self.generation == requestID else { return }
                if let json = result as? String, let data = json.data(using: .utf8),
                   let snapshot = try? JSONDecoder().decode(BrowseSnapshot.self, from: data), snapshot.ready {
                    let existing = Set(self.items.map(\.id))
                    let added = snapshot.items.filter { !existing.contains($0.id) }
                    let signature = snapshot.items.map(\.id).joined(separator: "|")
                    if signature == lastSignature, !append || !added.isEmpty {
                        if !append { self.items = snapshot.items }
                        else { self.items.append(contentsOf: added) }
                        self.page = self.pendingPage
                        self.canLoadMore = !added.isEmpty
                        self.hasLoaded = true
                        self.isLoading = false
                        self.error = nil
                        return
                    }
                    lastSignature = signature
                } else { lastSignature = nil }
            } catch { lastSignature = nil }
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
        }
        self.fail(append ? "No additional titles were returned. You may have reached the end; retry or open VIU." : "VIU's catalogue didn't finish loading. Please retry.")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { handle(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { handle(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail("VIU was interrupted. Please retry.") }
    private func handle(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        fail("Couldn't connect to VIU. Check your connection and retry.")
    }
    private func fail(_ message: String) {
        isLoading = false
        error = message
    }
}
