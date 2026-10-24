import SwiftUI
import AVKit
import WebKit

struct TitleDetailsView: View {
    let item: CatalogueItem
    @StateObject private var store = TitleDetailsStore()
    @State private var showsWebsite = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DetailReaderView(webView: store.webView)
                    .opacity(0).allowsHitTesting(false).accessibilityHidden(true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .top, spacing: 20) {
                            AsyncImage(url: item.poster) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(.quaternary).overlay { Image(systemName: "film") }
                            }
                                .frame(width: 120, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 10) {
                                Text(store.details?.title ?? item.title).font(.title2.bold())
                                Text(store.details?.year ?? item.year).foregroundStyle(.secondary)
                                if let details = store.details {
                                    Text(details.runtime).font(.subheadline).foregroundStyle(.secondary)
                                    if !details.rating.isEmpty {
                                        Label(details.rating, systemImage: "star.fill").font(.subheadline)
                                    }
                                }
                            }
                        }

                        if store.isLoading { ProgressView(store.isPreparingPlayback ? "Preparing playback…" : "Loading details…") }

                        if let details = store.details {
                            HStack(spacing: 16) {
                                if let favourite = details.isFavourite {
                                    Button { store.toggleSavedList(.favourites) } label: {
                                        Label(favourite ? "Favourited" : "Favourite", systemImage: favourite ? "heart.fill" : "heart")
                                    }
                                }
                                if let later = details.isWatchLater {
                                    Button { store.toggleSavedList(.watchLater) } label: {
                                        Label(later ? "Saved" : "Watch later", systemImage: later ? "bookmark.fill" : "bookmark")
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.isLoading || store.isPreparingPlayback || store.isUpdatingSavedList)
                            if store.isUpdatingSavedList { ProgressView("Updating saved list…") }
                            if details.seasons.isEmpty {
                                Button { store.preparePlayback() } label: {
                                    Label("Play movie", systemImage: "play.fill")
                                        .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(store.isLoading || store.isPreparingPlayback || store.isUpdatingSavedList)
                            } else {
                                Picker("Season", selection: Binding(
                                    get: { details.activeSeason },
                                    set: { id in
                                        if let season = details.seasons.first(where: { $0.id == id }) { store.selectSeason(season) }
                                    }
                                )) {
                                    ForEach(details.seasons) { season in Text(season.title).tag(season.id) }
                                }
                                .pickerStyle(.menu)
                                .disabled(store.isLoading || store.isPreparingPlayback || store.isUpdatingSavedList)
                                LazyVStack(spacing: 0) {
                                    ForEach(details.episodes) { episode in
                                        Button { store.playEpisode(episode) } label: {
                                            HStack(spacing: 16) {
                                                Text(episode.number).monospacedDigit().foregroundStyle(.secondary)
                                                Text(episode.title).frame(maxWidth: .infinity, alignment: .leading)
                                                Image(systemName: "play.circle.fill")
                                            }
                                            .padding(.vertical, 14)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(store.isLoading || store.isPreparingPlayback || store.isUpdatingSavedList)
                                        .accessibilityLabel("Play episode \(episode.number), \(episode.title)")
                                        Divider()
                                    }
                                }
                            }

                            if !details.genres.isEmpty {
                                Text(details.genres.joined(separator: " · "))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            if !details.synopsis.isEmpty {
                                Text("About").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                                Text(details.synopsis).lineSpacing(4)
                            }
                        }

                        if let error = store.error {
                            Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.secondary)
                            Button("Retry") { store.load(item.url) }
                        }
                        Button("Open on VIU", systemImage: "globe") { showsWebsite = true }
                    }.padding(24)
                }.background(Color(uiColor: .systemBackground))
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
            .task { store.load(item.url) }
            .onDisappear { store.cancel() }
            .sheet(isPresented: $showsWebsite) { VIUSignInView(url: item.url, title: item.title) }
            .fullScreenCover(item: $store.playback) { source in
                NativePlayerView(source: source, title: item.title)
            }
        }
    }
}

private struct DetailReaderView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct NativePlayerView: View {
    let title: String
    @StateObject private var session: NativePlayerSession
    @State private var playbackFailed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(source: PlaybackSource, title: String) {
        self.title = title
        _session = StateObject(wrappedValue: NativePlayerSession(source: source))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            SystemVideoPlayer(player: session.player).ignoresSafeArea()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.largeTitle)
                    .symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.6))
                    .frame(minWidth: 44, minHeight: 44)
            }.padding().accessibilityLabel("Close player")
            if playbackFailed {
                ContentUnavailableView {
                    Label("Playback couldn't start", systemImage: "play.slash")
                } description: {
                    Text("Close this player and retry to get a fresh link, or use Open on VIU.")
                } actions: { Button("Close player") { dismiss() } }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .preferredColorScheme(.dark)
            }
        }
        .onAppear {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                try AVAudioSession.sharedInstance().setActive(true)
                session.begin()
            } catch { playbackFailed = true }
        }
        .onReceive(session.item.publisher(for: \.status).receive(on: RunLoop.main)) { status in
            if status == .failed { playbackFailed = true }
            if status == .readyToPlay { session.startIfReady() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.saveProgress() } }
        .onDisappear {
            session.end()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        .accessibilityLabel(title)
    }
}

// Keep the presenting player alive during PiP so restoring the video returns
// to the same playback position without creating a second AVPlayer.
private struct SystemVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
            false
        }

        func playerViewController(_ playerViewController: AVPlayerViewController,
                                  restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            completionHandler(playerViewController.viewIfLoaded?.window != nil)
        }
    }
}

@MainActor
private final class NativePlayerSession: ObservableObject {
    let item: AVPlayerItem
    let player: AVPlayer
    private let resumeKey: String?
    private var isActive = false
    private var hasStarted = false

    init(source: PlaybackSource) {
        item = AVPlayerItem(url: source.url)
        player = AVPlayer(playerItem: item)
        resumeKey = source.resumeKey.map { "viu.resume.\($0)" }
    }

    func begin() {
        isActive = true
        startIfReady()
    }

    func startIfReady() {
        guard isActive, !hasStarted, item.status == .readyToPlay else { return }
        hasStarted = true
        let seconds = resumeKey.map { UserDefaults.standard.double(forKey: $0) } ?? 0
        let duration = item.duration.seconds
        if seconds.isFinite, seconds > 10, duration.isFinite, seconds < duration - 30 {
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.isActive else { return }
                    self.player.play()
                }
            }
        } else { player.play() }
    }

    func saveProgress() {
        guard let resumeKey else { return } // Live channels never resume.
        let seconds = player.currentTime().seconds
        let duration = item.duration.seconds
        guard seconds.isFinite, duration.isFinite, duration > 0 else { return }
        if seconds > 10, seconds < duration - 30 {
            UserDefaults.standard.set(seconds, forKey: resumeKey)
        } else { UserDefaults.standard.removeObject(forKey: resumeKey) }
    }

    func end() {
        isActive = false
        saveProgress()
        player.pause()
    }
}
