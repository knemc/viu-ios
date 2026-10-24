import Combine
import SwiftUI
import WebKit

@MainActor
final class AppSession: ObservableObject {
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
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.dataRecords(ofTypes: types)
        let viu = records.filter { $0.displayName == "viu.to" || $0.displayName.hasSuffix(".viu.to") }
        await dataStore.removeData(ofTypes: types, for: viu)
        clearProgress()
        generation = UUID() // Discard every native view's cached account data.
        isSigningOut = false
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
                    LabeledContent("Version", value: "0.1.0")
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
