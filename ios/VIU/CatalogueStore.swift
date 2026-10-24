import Combine
import Foundation
import WebKit

struct CatalogueItem: Decodable, Identifiable {
    let id: String
    let title: String
    let url: URL
    let poster: URL?
    let year: String
    let rating: String
}

struct CatalogueSection: Decodable, Identifiable {
    let id: String
    let items: [CatalogueItem]
}

private struct CatalogueSnapshot: Decodable {
    let sections: [CatalogueSection]
}

@MainActor
final class CatalogueStore: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var sections: [CatalogueSection] = []
    @Published private(set) var isLoading = false
    @Published private(set) var needsSignIn = false
    @Published private(set) var error: String?
    let webView: WKWebView
    private var generation = UUID()

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    func load() {
        cancel()
        isLoading = true
        error = nil
        webView.load(URLRequest(url: URL(string: "https://viu.to/")!))
    }

    func cancel() {
        generation = UUID()
        webView.stopLoading()
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView.url?.host == "viu.to" else {
            fail("VIU opened an unexpected page. Please retry.")
            return
        }
        if webView.url?.path == "/login" {
            sections = []
            needsSignIn = true
            isLoading = false
            return
        }
        needsSignIn = false
        guard let resource = Bundle.main.url(forResource: "Catalogue", withExtension: "js"),
              let script = try? String(contentsOf: resource, encoding: .utf8) else {
            fail("The catalogue reader is missing from this build.")
            return
        }
        let requestID = generation
        webView.evaluateJavaScript(script) { [weak self] result, scriptError in
            guard let self, self.generation == requestID else { return }
            self.isLoading = false
            guard scriptError == nil, let json = result as? String,
                  let data = json.data(using: .utf8),
                  let snapshot = try? JSONDecoder().decode(CatalogueSnapshot.self, from: data),
                  !snapshot.sections.isEmpty else {
                self.fail("VIU's catalogue could not be read. Retry or open the website.")
                return
            }
            self.sections = snapshot.sections
            self.needsSignIn = false
            self.error = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        fail("The connection to VIU was interrupted. Please retry.")
    }

    private func handle(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        fail("Couldn't connect to VIU. Check your connection and retry.")
    }

    private func fail(_ message: String) {
        isLoading = false
        error = message
    }
}
