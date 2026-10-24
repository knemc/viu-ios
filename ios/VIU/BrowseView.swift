import SwiftUI
import WebKit

struct BrowseView: View {
    let kind: CatalogueKind
    @StateObject private var store = BrowseStore()
    @State private var query = ""
    @State private var selection: CatalogueItem?
    @State private var showsWebsite = false
    @ScaledMetric(relativeTo: .body) private var cardWidth = 148.0

    var body: some View {
        NavigationStack {
            ZStack {
                BrowseSessionView(webView: store.webView)
                    .opacity(store.needsSignIn ? 1 : 0)
                    .allowsHitTesting(store.needsSignIn)
                    .accessibilityHidden(!store.needsSignIn)
                if !store.needsSignIn {
                    content.background(Color(uiColor: .systemBackground))
                }
            }
            .navigationTitle(store.needsSignIn ? "Sign in to VIU" : kind.title)
            .searchable(text: $query, prompt: "Search VIU")
            .task(id: query) {
                do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                store.search(kind: kind, query: query)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Refresh", systemImage: "arrow.clockwise") { store.search(kind: kind, query: query) }
                        Button("Open website", systemImage: "globe") { showsWebsite = true }
                    } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Browse options") }
                }
            }
            .sheet(item: $selection) { TitleDetailsView(item: $0) }
            .sheet(isPresented: $showsWebsite) {
                VIUSignInView(url: URL(string: "https://viu.to\(kind.path)")!, title: kind.title)
            }
            .onDisappear { store.cancel() }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: cardWidth), alignment: .top)], alignment: .leading, spacing: 24) {
                ForEach(store.items) { item in
                    Button { selection = item } label: { PosterCard(item: item) }
                        .buttonStyle(.plain)
                }
            }.padding()
            if store.isLoading { ProgressView("Loading \(kind.title.lowercased())…").padding() }
            if let error = store.error {
                VStack(spacing: 12) {
                    Label(error, systemImage: "wifi.exclamationmark")
                    Button("Retry") { store.retry() }.buttonStyle(.bordered)
                    Button("Open website") { showsWebsite = true }
                }.padding()
            } else if store.hasLoaded && store.items.isEmpty {
                ContentUnavailableView.search(text: query)
            } else if store.canLoadMore && !store.isLoading {
                Button("Load more") { store.loadMore() }
                    .buttonStyle(.bordered).padding()
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct BrowseSessionView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
