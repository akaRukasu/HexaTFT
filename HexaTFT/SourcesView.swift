import SwiftUI
import WebKit

enum ContentSource: String, CaseIterable, Identifiable {
    case mobalytics = "Mobalytics", metatft = "MetaTFT", blitz = "Blitz"
    var id: String { rawValue }
    var url: URL {
        switch self {
        case .mobalytics: return URL(string: "https://mobalytics.gg/tft/team-comps")!
        case .metatft: return URL(string: "https://www.metatft.com/comps")!
        case .blitz: return URL(string: "https://blitz.gg/tft/comps")!
        }
    }
}
@MainActor final class WebPage: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let view: WKWebView
    @Published var loading = false
    @Published var error: String?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var host = ""
    private let allowedHosts: Set<String>?
    init(url: URL, allowedHosts: Set<String>? = nil) {
        self.allowedHosts = allowedHosts
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        view = WKWebView(frame: .zero, configuration: config)
        super.init()
        view.navigationDelegate = self; view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.isOpaque = false; view.backgroundColor = .clear
        view.load(URLRequest(url: url))
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true; error = nil }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { update() }
    private func update() {
        loading = false; canGoBack = view.canGoBack; canGoForward = view.canGoForward; host = view.url?.host ?? ""
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError err: Error) {
        if (err as NSError).code != NSURLErrorCancelled { error = err.localizedDescription }; update()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError err: Error) {
        if (err as NSError).code != NSURLErrorCancelled { error = err.localizedDescription }; update()
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, ["https", "http", "about"].contains(url.scheme?.lowercased() ?? "") else { decisionHandler(.cancel); return }
        if let allowedHosts, navigationAction.targetFrame?.isMainFrame != false,
           (url.scheme != "https" || url.host.map(allowedHosts.contains) != true) {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url, ["https", "http"].contains(url.scheme ?? "") { webView.load(navigationAction.request) }
        return nil
    }
}
struct WebCanvas: UIViewRepresentable {
    let page: WebPage
    func makeUIView(context: Context) -> WKWebView { page.view }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
struct EmbeddedPage: View {
    @StateObject private var page: WebPage
    let home: URL
    init(url: URL, allowedHosts: Set<String>? = nil) {
        home = url
        _page = StateObject(wrappedValue: WebPage(url: url, allowedHosts: allowedHosts))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { page.view.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!page.canGoBack).accessibilityLabel("Page précédente")
                Button { page.view.goForward() } label: { Image(systemName: "chevron.right") }.disabled(!page.canGoForward).accessibilityLabel("Page suivante")
                Spacer()
                Text(page.host.isEmpty ? (home.host ?? "") : page.host).font(.caption).lineLimit(1)
                Spacer()
                Button { page.view.load(URLRequest(url: home)) } label: { Image(systemName: "house") }.accessibilityLabel("Accueil de la source")
                Button { page.view.reloadFromOrigin() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Recharger la page")
            }.padding(12).buttonStyle(.borderless)
            if page.loading { ProgressView().frame(maxWidth: .infinity).padding(4) }
            if let error = page.error {
                VStack(spacing: 12) {
                    Text("Cette page n’a pas pu être chargée.").font(.headline)
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Button("Réessayer") { page.view.load(URLRequest(url: home)) }.buttonStyle(.bordered)
                }.padding()
            }
            WebCanvas(page: page)
        }
    }
}
struct CurrentMetaSourcesView: View {
    @State private var selected = MetaObservation.Provider.codex

    var body: some View {
        VStack(spacing: 0) {
            Picker("Source", selection: $selected) {
                ForEach(MetaObservation.Provider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }.pickerStyle(.segmented).padding().accessibilityIdentifier("meta-web-source-picker")
            HStack {
                Text("Chiffres publiés par la source").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Link(destination: selected.currentCompsURL) {
                    Label("Site d’origine", systemImage: "arrow.up.right.square").font(.caption)
                }
            }.padding(.horizontal).padding(.bottom, 6)
            EmbeddedPage(url: selected.currentCompsURL, allowedHosts: selected.hosts)
                .id(selected)
        }
        .background(hexaNavy)
        .navigationTitle("Autres sources")
        .navigationBarTitleDisplayMode(.inline)
    }
}
struct SourcesView: View {
    @State private var selected = ContentSource.mobalytics
    @State private var visited: Set<ContentSource> = [.mobalytics]
    var body: some View {
        VStack(spacing: 0) {
            Picker("Source", selection: $selected) {
                ForEach(ContentSource.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).padding()
            ZStack {
                ForEach(ContentSource.allCases) { source in
                    if visited.contains(source) {
                        Group {
                            if source == .mobalytics || source == .blitz {
                                VStack(spacing: 12) {
                                    Text(source.rawValue).font(.title2.bold())
                                    Link("Ouvrir le site original", destination: source.url)
                                        .buttonStyle(.borderedProminent)
                                        .accessibilityIdentifier("source-original-" + source.rawValue)
                                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else { EmbeddedPage(url: source.url) }
                        }.opacity(selected == source ? 1 : 0)
                            .allowsHitTesting(selected == source).accessibilityHidden(selected != source)
                    }
                }
            }
        }
        .onChange(of: selected) { _, value in visited.insert(value) }
        .navigationTitle("Toutes les sources").navigationBarTitleDisplayMode(.inline)
    }
}
