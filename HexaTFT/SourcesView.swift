import SwiftUI
import WebKit

private struct TFTSource: Identifiable {
    enum Category: String, CaseIterable, Identifiable {
        case stats = "Statistiques", guides = "Guides", tools = "Outils et références"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .stats: "chart.bar.xaxis"
            case .guides: "book.closed"
            case .tools: "wrench.and.screwdriver"
            }
        }
    }
    let id: String
    let name: String
    let description: String
    let url: URL
    let category: Category
    let external: Bool

    init(_ id: String, _ name: String, _ description: String, _ url: URL, _ category: Category, external: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.url = url
        self.category = category
        self.external = external
    }

    static let all: [Self] = [
        .init("opgg", "OP.GG", "Statistiques synchronisées dans Méta", OPGGMetaSnapshot.source, .stats),
        .init("codex", "TFT Codex", "Classements et variantes par rang", MetaObservation.Provider.codex.currentCompsURL, .stats),
        .init("tactics", "Tactics.Tools", "Compositions, variantes et objets", MetaObservation.Provider.tactics.currentCompsURL, .stats),
        .init("metastats", "MetaStats.gg", "Atlas et filtres de rang", MetaObservation.Provider.metastats.currentCompsURL, .stats),
        .init("metatft", "MetaTFT", "Compositions issues des matchs classés", URL(string: "https://www.metatft.com/comps")!, .stats),
        .init("blitz", "Blitz", "Compositions et builds", URL(string: "https://blitz.gg/tft/comps")!, .stats, external: true),
        .init("ninja", "TFT Ninja", "Plateaux et statistiques du patch", URL(string: "https://tft.ninja/comps")!, .stats),
        .init("tftable", "TFTable", "Atlas des compositions et tendances", URL(string: "https://www.tftable.cc/comps")!, .stats),
        .init("lolchess", "LoLCHESS.GG", "Compositions et classements · Corée", URL(string: "https://lolchess.gg/")!, .stats),
        .init("academy", "TFT Academy", "Tier list et guides de joueurs experts", URL(string: "https://tftacademy.com/tierlist/comps")!, .guides),
        .init("sologesang", "Sologesang Pro Comps", "Sélection de Sologesang sur MetaTFT", URL(string: "https://www.metatft.com/pro-comps")!, .guides),
        .init("flow", "TFT Flow", "Choix de compo selon ton départ", URL(string: "https://tftflow.com/")!, .guides),
        .init("mobalytics", "Mobalytics", "Guides et compositions Challenger", URL(string: "https://mobalytics.gg/tft/team-comps")!, .guides, external: true),
        .init("casita", "La Casita del TFT", "Tier list et plans de jeu", URL(string: "https://lacasitadeltft.com/en/tierlist/comps")!, .guides),
        .init("bunny", "BunnyMuffins", "Sélection méta et guides", URL(string: "https://bunnymuffins.lol/meta/")!, .guides, external: true),
        .init("hexcomps", "HexComps", "Guides par stade et placements", URL(string: "https://hexcomps.com/fr/")!, .guides),
        .init("handbook", "TFT Handbook", "Plans de jeu de Robinsongz", URL(string: "https://tfthandbook.com/")!, .guides),
        .init("tftips", "TFTips", "Outils et références du jeu", URL(string: "https://tftips.app/")!, .tools, external: true),
        .init("tftraits", "TFTraits", "Recherche de synergies et planificateur", URL(string: "https://tftraits.com/")!, .tools),
        .init("pbe", "PBE · Tactics.Tools", "Unités et synergies du set en test", URL(string: "https://tactics.tools/info/pbe")!, .tools),
        .init("riot", "Riot Games", "Notes officielles du patch", URL(string: "https://teamfighttactics.leagueoflegends.com/fr-fr/news/game-updates/")!, .tools),
        .init("dragon", "CommunityDragon", "Données du client utilisées dans le Codex", URL(string: "https://www.communitydragon.org/")!, .tools),
        .init("compete", "Compete TFT", "Tournois et calendrier officiel", URL(string: "https://competetft.com/en-US/schedule")!, .tools)
    ]

    var hosts: Set<String> {
        guard let host = url.host else { return [] }
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return [domain, "www." + domain]
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
struct SourcesView: View {
    @State private var query = ""
    private var sources: [TFTSource] {
        TFTSource.all.filter { query.isEmpty || ($0.name + " " + $0.description).localizedStandardContains(query) }
    }

    var body: some View {
        List {
            ForEach(TFTSource.Category.allCases) { category in
                let group = sources.filter { $0.category == category }
                if !group.isEmpty {
                    Section(category.rawValue) {
                        ForEach(group) { source in
                            NavigationLink { SourcePage(source: source) } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(source.name).font(.headline)
                                        Text(source.description).font(.caption).foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: category.icon).foregroundStyle(category == .stats ? .mint : hexaGold)
                                }
                            }.accessibilityIdentifier("provider-" + source.id)
                        }
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(hexaNavy)
            .overlay { if sources.isEmpty { ContentUnavailableView.search(text: query) } }
            .searchable(text: $query, prompt: "Chercher une source")
            .navigationTitle("Toutes les sources").navigationBarTitleDisplayMode(.inline)
    }
}

private struct SourcePage: View {
    let source: TFTSource
    var body: some View {
        Group {
            if source.external {
                VStack(alignment: .leading, spacing: 18) {
                    FeatureBanner(eyebrow: source.category.rawValue, title: source.name, detail: source.description, icon: source.category.icon)
                    Link(destination: source.url) {
                        Label("Ouvrir le site original", systemImage: "arrow.up.right.square")
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("source-original-" + source.name)
                    Spacer()
                }.padding()
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Page du fournisseur").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Link(destination: source.url) {
                            Label("Site d’origine", systemImage: "arrow.up.right.square").font(.caption)
                        }
                    }.padding(.horizontal).padding(.top, 8)
                    EmbeddedPage(url: source.url, allowedHosts: source.hosts)
                }
            }
        }.background(hexaNavy).navigationTitle(source.name).navigationBarTitleDisplayMode(.inline)
    }
}
