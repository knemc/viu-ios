import Combine
import Foundation
import WebKit

struct TitleDetails: Decodable {
    struct Season: Decodable, Identifiable {
        let id: String
        let title: String
    }
    struct Episode: Decodable, Identifiable {
        let id: String
        let number: String
        let title: String
    }
    let title: String
    let synopsis: String
    let year: String
    let runtime: String
    let rating: String
    let isFavourite: Bool?
    let isWatchLater: Bool?
    let genres: [String]
    let media: URL?
    let seasons: [Season]
    let activeSeason: String
    let activeEpisode: String
    let playerLabel: String
    let episodes: [Episode]
}

struct PlaybackSource: Identifiable {
    let id = UUID()
    let url: URL
    let resumeKey: String?
    init(url: URL, resumeKey: String? = nil) {
        self.url = url
        self.resumeKey = resumeKey
    }
}

enum SavedList: String {
    case favourites = "favorites-add"
    case watchLater = "watchlist-add"
    func value(in details: TitleDetails) -> Bool? {
        self == .favourites ? details.isFavourite : details.isWatchLater
    }
}

@MainActor
final class TitleDetailsStore: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var details: TitleDetails?
    @Published private(set) var isLoading = false
    @Published private(set) var isPreparingPlayback = false
    @Published private(set) var error: String?
    @Published private(set) var isUpdatingSavedList = false
    @Published var playback: PlaybackSource?
    let webView: WKWebView
    private var pageURL: URL?
    private var readTask: Task<Void, Never>?
    private var pendingEpisode: (season: TitleDetails.Season, episode: TitleDetails.Episode)?
    private var generation = UUID()
    private var pendingSavedList: (list: SavedList, desired: Bool)?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    func load(_ url: URL) {
        guard url.scheme == "https", url.host == "viu.to",
              url.path.hasPrefix("/wm/") || url.path.hasPrefix("/wtv/") else {
            fail("This title link isn't supported.")
            return
        }
        readTask?.cancel()
        generation = UUID()
        pageURL = url
        isLoading = true
        error = nil
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
    }

    func preparePlayback() {
        guard let pageURL else { return }
        pendingEpisode = nil
        isPreparingPlayback = true
        // Signed media URLs expire. Resolve from a fresh page for every play.
        load(pageURL)
    }

    func cancel() {
        generation = UUID()
        readTask?.cancel()
        readTask = nil
        webView.stopLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView.url?.host == "viu.to", webView.url?.path != "/login" else {
            fail("Your session has expired. Open the VIU website to sign in again.")
            return
        }
        readTask?.cancel()
        let requestID = generation
        readTask = Task { [weak self] in
            guard let self else { return }
            guard let resource = Bundle.main.url(forResource: "TitleDetails", withExtension: "js"),
                  let script = try? String(contentsOf: resource, encoding: .utf8) else {
                self.fail("The title reader is missing from this build.")
                return
            }
            // VIU attaches its video after page load; allow bounded time for it.
            for attempt in 0..<16 {
                guard !Task.isCancelled, self.generation == requestID else { return }
                do {
                    let result = try await self.webView.evaluateJavaScript(script)
                    guard !Task.isCancelled, self.generation == requestID else { return }
                    if let json = result as? String, let data = json.data(using: .utf8),
                       let value = try? JSONDecoder().decode(TitleDetails.self, from: data),
                       !value.title.isEmpty {
                        self.details = value
                        if let pending = self.pendingSavedList {
                            if pending.list.value(in: value) == pending.desired {
                                self.pendingSavedList = nil
                                self.isUpdatingSavedList = false
                            } else {
                                self.fail("VIU hasn't confirmed the saved-list change. Please retry.")
                                return
                            }
                        }
                        if self.isPreparingPlayback, let pending = self.pendingEpisode {
                            await self.resolveEpisode(season: pending.season, episode: pending.episode, requestID: requestID)
                            return
                        }
                        if !self.isPreparingPlayback {
                            self.isLoading = false
                            if !value.seasons.isEmpty, value.episodes.isEmpty,
                               let season = value.seasons.first(where: { $0.id == value.activeSeason }) ?? value.seasons.first {
                                await self.resolveSeason(season, requestID: requestID)
                            }
                            return
                        }
                        if let media = value.media, media.scheme == "https", value.seasons.isEmpty {
                            self.playback = PlaybackSource(url: media, resumeKey: self.pageURL?.path)
                            self.isLoading = false
                            self.isPreparingPlayback = false
                            return
                        }
                    }
                } catch {
                    if attempt == 15 { break }
                }
                do { try await Task.sleep(for: .milliseconds(500)) }
                catch { return }
            }
            self.fail(self.isPreparingPlayback
                ? "VIU hasn't supplied a playable movie link. Try again or use the website player."
                : "This title couldn't be read. Try again or open the website.")
        }
    }

    func toggleSavedList(_ list: SavedList) {
        guard !isLoading, !isPreparingPlayback, !isUpdatingSavedList,
              let details, let current = list.value(in: details), let pageURL else { return }
        isUpdatingSavedList = true
        error = nil
        readTask?.cancel()
        generation = UUID()
        let requestID = generation
        readTask = Task { [weak self] in
            guard let self else { return }
            do {
                let script = """
                (() => {
                    const e = document.querySelector('.\(list.rawValue)');
                    if (!e) return false;
                    e.click(); return true;
                })();
                """
                guard let clicked = try await self.webView.evaluateJavaScript(script) as? Bool, clicked else {
                    throw ReaderError.unavailable
                }
                for _ in 0..<20 {
                    try await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled, self.generation == requestID else { return }
                    let value = try await self.snapshot()
                    guard !Task.isCancelled, self.generation == requestID else { return }
                    if list.value(in: value) == !current {
                        self.pendingSavedList = (list, !current)
                        // Verify the saved state on a new page rather than
                        // treating VIU's optimistic CSS change as persistence.
                        self.load(pageURL)
                        return
                    }
                }
                self.fail("VIU didn't confirm the saved-list change. Please retry.")
            } catch {
                guard !Task.isCancelled, self.generation == requestID else { return }
                self.fail("Couldn't update your saved list. Please retry.")
            }
        }
    }

    func selectSeason(_ season: TitleDetails.Season) {
        guard !isLoading, !isPreparingPlayback else { return }
        readTask?.cancel()
        generation = UUID()
        let requestID = generation
        readTask = Task { [weak self] in
            guard let self else { return }
            await self.resolveSeason(season, requestID: requestID)
        }
    }

    func playEpisode(_ episode: TitleDetails.Episode) {
        guard let details, let season = details.seasons.first(where: { $0.id == details.activeSeason }),
              details.episodes.contains(where: { $0.id == episode.id }), let pageURL else { return }
        pendingEpisode = (season, episode)
        isPreparingPlayback = true
        load(pageURL)
    }

    private func snapshot() async throws -> TitleDetails {
        guard let resource = Bundle.main.url(forResource: "TitleDetails", withExtension: "js") else { throw ReaderError.unavailable }
        let script = try String(contentsOf: resource, encoding: .utf8)
        let result = try await webView.evaluateJavaScript(script)
        guard let json = result as? String, let data = json.data(using: .utf8) else { throw ReaderError.unavailable }
        return try JSONDecoder().decode(TitleDetails.self, from: data)
    }

    private func clickElement(id: String, expectedClass: String) async throws {
        let encoded = String(data: try JSONEncoder().encode(id), encoding: .utf8)!
        let script = """
        (() => {
            const e = document.getElementById(\(encoded));
            if (!e || !e.classList.contains('\(expectedClass)')) return false;
            e.click(); return true;
        })();
        """
        guard let clicked = try await webView.evaluateJavaScript(script) as? Bool, clicked else { throw ReaderError.unavailable }
    }

    private func resolveSeason(_ season: TitleDetails.Season, requestID: UUID) async {
        guard details?.seasons.contains(where: { $0.id == season.id }) == true else { return }
        isLoading = true
        error = nil
        do {
            try await clickElement(id: season.id, expectedClass: "li-season")
            for _ in 0..<24 {
                guard !Task.isCancelled, generation == requestID else { return }
                let value = try await snapshot()
                guard !Task.isCancelled, generation == requestID else { return }
                if value.activeSeason == season.id, !value.episodes.isEmpty {
                    details = value
                    isLoading = false
                    return
                }
                try await Task.sleep(for: .milliseconds(400))
            }
            fail("This season has no available episodes, or VIU didn't finish loading. Retry or open VIU.")
        } catch {
            guard !Task.isCancelled, generation == requestID else { return }
            fail("Couldn't load the selected season. Please retry.")
        }
    }

    private func resolveEpisode(season: TitleDetails.Season, episode: TitleDetails.Episode, requestID: UUID) async {
        await resolveSeason(season, requestID: requestID)
        guard !Task.isCancelled, generation == requestID, error == nil,
              details?.activeSeason == season.id,
              details?.episodes.contains(where: { $0.id == episode.id }) == true else { return }
        isLoading = true
        do {
            let previous = try await snapshot()
            try await clickElement(id: episode.id, expectedClass: "li-episode")
            for _ in 0..<24 {
                guard !Task.isCancelled, generation == requestID else { return }
                let value = try await snapshot()
                guard !Task.isCancelled, generation == requestID else { return }
                let expected = "\(season.title) Episode \(episode.number) - \(episode.title)"
                // Season selection alone can leave the previous episode's video
                // behind. Require both the player identity and changed media.
                let alreadyCorrect = previous.activeEpisode == episode.id && previous.playerLabel.contains(expected)
                if value.activeEpisode == episode.id, value.playerLabel.contains(expected),
                   let media = value.media, media.scheme == "https",
                   (media != previous.media || alreadyCorrect) {
                    details = value
                    playback = PlaybackSource(url: media, resumeKey: pageURL.map { "\($0.path)/episode/\(episode.id)" })
                    isLoading = false
                    isPreparingPlayback = false
                    pendingEpisode = nil
                    return
                }
                try await Task.sleep(for: .milliseconds(400))
            }
            fail("VIU couldn't confirm the selected episode's video. Retry or use the website player.")
        } catch {
            guard !Task.isCancelled, generation == requestID else { return }
            fail("Couldn't prepare this episode. Please retry.")
        }
    }

    private enum ReaderError: Error { case unavailable }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationFailed(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationFailed(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        fail("The connection to this title was interrupted. Please retry.")
    }

    private func navigationFailed(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        fail("Couldn't load this title. Check your connection and retry.")
    }

    private func fail(_ message: String) {
        isLoading = false
        isPreparingPlayback = false
        error = message
        pendingEpisode = nil
        pendingSavedList = nil
        isUpdatingSavedList = false
    }
}
