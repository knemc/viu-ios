import Combine
import Foundation
import WebKit

struct LiveChannel: Decodable, Identifiable {
    let id: String
    let title: String
    let url: URL
}

private struct LiveSnapshot: Decodable {
    let channels: [LiveChannel]
    let stream: URL?
}

@MainActor
final class LiveTVStore: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var channels: [LiveChannel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var needsSignIn = false
    @Published private(set) var error: String?
    @Published private(set) var selected: LiveChannel?
    @Published var playback: PlaybackSource?
    let webView: WKWebView
    private var readTask: Task<Void, Never>?
    private var generation = UUID()

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = AppSession.websiteDataStore
        config.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
    }

    func refresh() {
        selected = nil
        load(URL(string: "https://viu.to/live-tv")!)
    }

    func play(_ channel: LiveChannel) {
        guard channels.contains(where: { $0.id == channel.id }), !isLoading else { return }
        selected = channel
        load(channel.url)
    }

    func retry() {
        if let selected { load(selected.url) } else { refresh() }
    }

    func cancel() {
        generation = UUID()
        readTask?.cancel()
        webView.stopLoading()
        isLoading = false
    }

    private func load(_ url: URL) {
        cancel()
        error = nil
        isLoading = true
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView.url?.host == "viu.to" else { fail("VIU opened an unexpected page."); return }
        if webView.url?.path == "/login" {
            channels = []
            needsSignIn = true
            isLoading = false
            return
        }
        if needsSignIn {
            needsSignIn = false
            refresh()
            return
        }
        guard webView.url?.path == (selected?.url.path ?? "/live-tv") else {
            fail("This channel page could not be opened. Refresh the channel list."); return
        }
        readTask?.cancel()
        let requestID = generation
        readTask = Task { [weak self] in
            guard let self else { return }
            guard let resource = Bundle.main.url(forResource: "LiveTV", withExtension: "js"),
                  let script = try? String(contentsOf: resource, encoding: .utf8) else {
                self.fail("The channel reader is missing from this build."); return
            }
            for _ in 0..<30 {
                guard !Task.isCancelled, self.generation == requestID else { return }
                do {
                    let result = try await self.webView.evaluateJavaScript(script)
                    guard !Task.isCancelled, self.generation == requestID else { return }
                    if let json = result as? String, let data = json.data(using: .utf8),
                       let snapshot = try? JSONDecoder().decode(LiveSnapshot.self, from: data) {
                        if self.selected == nil, !snapshot.channels.isEmpty {
                            self.channels = snapshot.channels
                            self.isLoading = false
                            return
                        }
                        if self.selected != nil, let stream = snapshot.stream, stream.scheme == "https" {
                            self.playback = PlaybackSource(url: stream)
                            self.isLoading = false
                            return
                        }
                    }
                    try await Task.sleep(for: .milliseconds(400))
                } catch {
                    guard !Task.isCancelled, self.generation == requestID else { return }
                    self.fail("Couldn't read Live TV. Retry or open VIU."); return
                }
            }
            self.fail("VIU hasn't supplied \(self.selected == nil ? "a channel list" : "a playable channel link"). Retry or open VIU.")
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { handle(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { handle(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail("VIU was interrupted. Please retry.") }
    private func handle(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        fail("Couldn't connect to Live TV. Check your connection and retry.")
    }
    private func fail(_ message: String) {
        isLoading = false
        error = message
    }
}
