import SwiftUI
import WebKit

// Authentication stays on VIU's real page; credentials and CAPTCHA responses
// are never collected by native fields or injected scripts.
struct VIUSignInView: View {
    @Environment(\.dismiss) private var dismiss
    var url: URL = URL(string: "https://viu.to/login")!
    var title: String = "Sign in · viu.to"

    var body: some View {
        NavigationStack {
            SignInWebView(url: url)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

private struct SignInWebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = AppSession.websiteDataStore
        configuration.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
