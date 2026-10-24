import Combine
import SwiftUI
import WebKit

@MainActor
final class AppSession: ObservableObject {
    private static let profileKey = "viu.webProfile"
    static var websiteDataStore: WKWebsiteDataStore {
        if let stored = UserDefaults.standard.string(forKey: profileKey), let identifier = UUID(uuidString: stored) {
            return WKWebsiteDataStore(forIdentifier: identifier)
        }
        // Preserve sign-in from early test builds until the first sign-out.
        return .default()
    }
    @Published private(set) var generation = UUID()
    @Published private(set) var isSigningOut = false

    func clearProgress() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("viu.resume.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        let previousStore = Self.websiteDataStore
        let previousIdentifier = previousStore.identifier
        // Switching profile immediately prevents reuse of the old cookies.
        // WebKit's disk cleanup can be slow and must not block navigation.
        UserDefaults.standard.set(UUID().uuidString, forKey: Self.profileKey)
        clearProgress()
        generation = UUID() // Discard every native view's cached account data.
        isSigningOut = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if let previousIdentifier {
                for _ in 0..<3 {
                    do {
                        try await WKWebsiteDataStore.remove(forIdentifier: previousIdentifier)
                        return
                    } catch { try? await Task.sleep(for: .seconds(1)) }
                }
            } else {
                await previousStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
            }
        }
    }
}

struct AccountView: View {
    @EnvironmentObject private var session: AppSession
    @State private var destination: AccountPage?
    @State private var confirmsSignOut = false
    @State private var confirmsClear = false

    var body: some View {
        NavigationStack {
            List {
                Section("Your VIU account") {
                    Button("Account settings", systemImage: "person.crop.circle") { destination = .settings }
                    Button("Favourites on VIU", systemImage: "heart") { destination = .favourites }
                    Button("Watch later on VIU", systemImage: "bookmark") { destination = .watchLater }
                }
                Section {
                    Button("Clear local playback progress", systemImage: "clock.arrow.circlepath") { confirmsClear = true }
                    Button("Sign out on this iPhone", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { confirmsSignOut = true }
                        .disabled(session.isSigningOut)
                } header: { Text("On this iPhone") } footer: {
                    Text("Movie and episode playback resumes from the position saved on this iPhone. Progress is not synced with VIU's website.")
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                    Text("An independent personal client for your existing VIU account.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Account")
            .sheet(item: $destination) { page in VIUSignInView(url: page.url, title: page.title) }
            .confirmationDialog("Sign out on this iPhone?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { Task { await session.signOut() } }
            }
            .confirmationDialog("Clear playback positions saved on this iPhone?", isPresented: $confirmsClear, titleVisibility: .visible) {
                Button("Clear progress", role: .destructive) { session.clearProgress() }
            }
            .overlay { if session.isSigningOut { ProgressView("Signing out…") } }
        }
    }
}

private enum AccountPage: String, Identifiable {
    case settings, favourites, watchLater
    var id: Self { self }
    var title: String {
        switch self { case .settings: "Settings"; case .favourites: "Favourites"; case .watchLater: "Watch later" }
    }
    var url: URL {
        let path: String
        switch self { case .settings: path = "setup"; case .favourites: path = "favorites"; case .watchLater: path = "watchlist" }
        return URL(string: "https://viu.to/user/\(path)")!
    }
}
