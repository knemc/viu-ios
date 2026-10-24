import SwiftUI
import WebKit

struct LiveTVView: View {
    @StateObject private var store = LiveTVStore()
    @State private var query = ""
    @State private var showsWebsite = false

    private var filtered: [LiveChannel] {
        store.channels.filter { query.isEmpty || $0.title.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiveSessionView(webView: store.webView)
                    .opacity(store.needsSignIn ? 1 : 0)
                    .allowsHitTesting(store.needsSignIn)
                    .accessibilityHidden(!store.needsSignIn)
                if !store.needsSignIn {
                    List {
                        if store.isLoading {
                            ProgressView(store.selected.map { "Opening \($0.title)…" } ?? "Loading channels…")
                        }
                        if let error = store.error {
                            Section {
                                Label(error, systemImage: "exclamationmark.circle")
                                Button("Retry") { store.retry() }
                                Button("Open on VIU") { showsWebsite = true }
                            }
                        }
                        if !store.isLoading && store.error == nil && filtered.isEmpty {
                            ContentUnavailableView.search(text: query)
                        }
                        ForEach(filtered) { channel in
                            Button { store.play(channel) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "tv").foregroundStyle(.secondary)
                                    Text(channel.title).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                }.padding(.vertical, 8)
                            }
                            .disabled(store.isLoading)
                            .accessibilityLabel("Watch \(channel.title)")
                        }
                    }.listStyle(.insetGrouped)
                }
            }
            .navigationTitle(store.needsSignIn ? "Sign in to VIU" : "Live TV")
            .searchable(text: $query, prompt: "Find a channel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Refresh channels", systemImage: "arrow.clockwise") { store.refresh() }
                        Button("TV guide", systemImage: "calendar") { showsWebsite = true }
                    } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Live TV options") }
                }
            }
            .task { if store.channels.isEmpty { store.refresh() } }
            .onDisappear { store.cancel() }
            .fullScreenCover(item: $store.playback) { source in
                NativePlayerView(source: source, title: store.selected?.title ?? "Live TV")
            }
            .sheet(isPresented: $showsWebsite) {
                VIUSignInView(url: store.error != nil ? (store.selected?.url ?? URL(string: "https://viu.to/live-tv")!) : URL(string: "https://viu.to/tvguide/")!, title: "Live TV")
            }
        }
    }
}

private struct LiveSessionView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
