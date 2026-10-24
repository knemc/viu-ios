import SwiftUI
import WebKit

@main
struct VIUApp: App {
    @StateObject private var session = AppSession()
    var body: some Scene {
        WindowGroup {
            Group {
                if session.isSigningOut {
                    ProgressView("Signing out…")
                } else {
                    TabView {
                        CatalogueView().tabItem { Label("Home", systemImage: "house") }
                        BrowseView(kind: .movies).tabItem { Label("Movies", systemImage: "film") }
                        BrowseView(kind: .series).tabItem { Label("TV", systemImage: "tv") }
                        LiveTVView().tabItem { Label("Live", systemImage: "dot.radiowaves.left.and.right") }
                        AccountView().tabItem { Label("Account", systemImage: "person.crop.circle") }
                    }
                }
            }
            .id(session.generation)
            .environmentObject(session)
            .tint(.indigo)
        }
    }
}

private struct CatalogueView: View {
    @StateObject private var store = CatalogueStore()
    @State private var selection: CatalogueItem?
    @State private var showsWebsite = false
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ZStack {
                SessionWebView(webView: store.webView)
                    .opacity(store.needsSignIn ? 1 : 0)
                    .allowsHitTesting(store.needsSignIn)
                    .accessibilityHidden(!store.needsSignIn)
                if !store.needsSignIn {
                    catalogue.background(Color(uiColor: .systemBackground))
                }
            }
            .navigationTitle(store.needsSignIn ? "Sign in to VIU" : "VIU")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Refresh", systemImage: "arrow.clockwise") { store.load() }
                        Button("Open VIU website", systemImage: "globe") { showsWebsite = true }
                    } label: {
                        Image(systemName: "ellipsis.circle").accessibilityLabel("Options")
                    }
                }
            }
            .sheet(item: $selection, onDismiss: { store.load() }) { item in
                TitleDetailsView(item: item)
            }
            .sheet(isPresented: $showsWebsite) {
                VIUSignInView(url: URL(string: "https://viu.to/")!, title: "VIU website")
            }
            .task { if store.sections.isEmpty { store.load() } }
            .onDisappear { store.cancel() }
        }
        .tint(.indigo)
    }

    @ViewBuilder private var catalogue: some View {
        if store.sections.isEmpty {
            if store.isLoading {
                ProgressView("Connecting to VIU…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("Couldn't load VIU", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(store.error ?? "Try connecting again.")
                } actions: {
                    Button("Retry") { store.load() }.buttonStyle(.borderedProminent)
                    Button("Open website") { showsWebsite = true }
                }
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if let error = store.error {
                        Text(error).font(.callout).foregroundStyle(.secondary).padding(.horizontal)
                    }
                    if !query.isEmpty {
                        Text("Search in loaded titles")
                            .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                    }
                    let visible = store.sections.filter { section in
                        section.items.contains { matches($0) }
                    }
                    if visible.isEmpty { ContentUnavailableView.search(text: query) }
                    ForEach(visible) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.id).font(.title2.bold()).padding(.horizontal)
                                .accessibilityAddTraits(.isHeader)
                            ScrollView(.horizontal) {
                                LazyHStack(alignment: .top, spacing: 14) {
                                    ForEach(section.items.filter { matches($0) }) { item in
                                        Button { selection = item } label: { PosterCard(item: item) }
                                            .buttonStyle(.plain)
                                    }
                                }.padding(.horizontal)
                            }.scrollIndicators(.hidden)
                        }
                    }
                }.padding(.vertical)
            }
            .searchable(text: $query, prompt: "Find in loaded titles")
            .overlay(alignment: .topTrailing) {
                if store.isLoading { ProgressView().padding() }
            }
        }
    }

    private func matches(_ item: CatalogueItem) -> Bool {
        query.isEmpty || item.title.localizedStandardContains(query)
    }
}

struct PosterCard: View {
    let item: CatalogueItem
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: item.poster) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary)
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }
            .frame(width: 148, height: 222)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            HStack {
                Text(item.year)
                if !item.rating.isEmpty { Label(item.rating, systemImage: "star.fill") }
            }.font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 148, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens title details")
    }
}

private struct SessionWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
