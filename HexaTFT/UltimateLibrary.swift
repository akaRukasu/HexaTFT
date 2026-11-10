import SwiftUI
import Foundation

struct RiotArticle: Codable, Identifiable {
    let title: String
    let path: String
    var id: String { path }
    var url: URL { URL(string: "https://teamfighttactics.leagueoflegends.com" + path)! }
}
struct RiotNewsSnapshot: Codable {
    let articles: [RiotArticle]
    let checked: Date
}
@MainActor final class RiotNewsStore: ObservableObject {
    @Published private(set) var esports: RiotNewsSnapshot?
    @Published private(set) var patches: RiotNewsSnapshot?
    private let directory = URL.applicationSupportDirectory.appendingPathComponent("HexaTFT")
    private var lastAttempt: Date?
    private var refreshing = false
    init() {
        esports = load("esports")
        patches = load("game-updates")
    }
    func refresh() async {
        guard !refreshing, lastAttempt.map({ Date().timeIntervalSince($0) >= 300 }) ?? true else { return }
        refreshing = true; lastAttempt = Date()
        defer { refreshing = false }
        async let esportsResult = Self.fetch("esports")
        async let patchResult = Self.fetch("game-updates")
        if let result = await esportsResult { save(result, topic: "esports"); esports = result }
        if let result = await patchResult { save(result, topic: "game-updates"); patches = result }
    }
    private func load(_ topic: String) -> RiotNewsSnapshot? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("riot-" + topic + ".json")) else { return nil }
        return try? JSONDecoder().decode(RiotNewsSnapshot.self, from: data)
    }
    private func save(_ value: RiotNewsSnapshot, topic: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(value).write(to: directory.appendingPathComponent("riot-" + topic + ".json"), options: .atomic)
    }
    nonisolated private static func fetch(_ topic: String) async -> RiotNewsSnapshot? {
        let url = URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/" + topic + "/")!
        guard let data = try? await DragonFeed.get(url, max: 3_000_000),
              let html = String(data: data, encoding: .utf8) else { return nil }
        let items = parse(html, topic: topic)
        return items.isEmpty ? nil : RiotNewsSnapshot(articles: items, checked: Date())
    }
    nonisolated static func parse(_ html: String, topic: String) -> [RiotArticle] {
        guard ["esports", "game-updates"].contains(topic) else { return [] }
        let pattern = #"<a\b[^>]*aria-label="([^"]+)"[^>]*href="(/en-us/news/"# + topic + #"/[a-z0-9-]+/?)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = html as NSString
        var seen: Set<String> = []
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { hit in
            let path = ns.substring(with: hit.range(at: 2))
            guard seen.insert(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).inserted else { return nil }
            let title = ns.substring(with: hit.range(at: 1)).replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&#x27;", with: "'")
            return RiotArticle(title: title, path: path)
        }
    }
}


struct EsportEvent: Identifiable {
    let id: String
    let title: String
    let region: String
    let dates: String
    let format: String
    let icon: String
    let url: URL

    static let crown = Self(id: "crown", title: "Tactician’s Crown", region: "Mondial", dates: "13–15 novembre 2026",
        format: "La finale mondiale du set 18 réunit 40 tacticiens en trois journées.",
        icon: "crown", url: URL(string: "https://teamfighttactics.leagueoflegends.com/fr-fr/news/esports/regional-finals-2026-everything-you-need-to-know/")!)
    static let superbrawl = Self(id: "superbrawl", title: "Tactician’s Superbrawl", region: "EMEA · AMER · APAC", dates: "6–8 novembre 2026",
        format: "Tournoi par équipes de quatre, avec une finale en cinq manches maximum.",
        icon: "person.3.sequence", url: URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/tacticians-superbrawl-teams-dates-and-format/")!)
    static let regional = Self(id: "regional", title: "Finales régionales", region: "EMEA · AMER · APAC", dates: "23–25 oct. et 30 oct.–1 nov. 2026",
        format: "Deux week-ends de qualification pour le mondial, avec 64 tacticiens dans chaque région.",
        icon: "globe.europe.africa", url: crown.url)

    static let roadmap = URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/compete-in-enchanted-wilds/")!
    static let schedule = URL(string: "https://competetft.com/schedule")!
    static let twitch = URL(string: "https://www.twitch.tv/teamfighttactics")!
    static let youtube = URL(string: "https://www.youtube.com/@playtft/streams")!
    static let huanmie = URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/5-questions-with-aur-huanmie-the-space-gods-champion/")!
}

struct EsportView: View {
    @EnvironmentObject private var news: RiotNewsStore
    @State private var tab: Tab = .watch
    @AppStorage("hexa.follow.huanmie") private var followHuanmie = false

    enum Tab: String, CaseIterable {
        case watch = "En direct", calendar = "Calendrier", results = "Résultats", players = "Joueurs"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                FeatureBanner(eyebrow: "HEXA ARENA · SET 18", title: "TFT Esport",
                              detail: "Compétitions, diffusions et résultats officiels", icon: "trophy")
                Picker("Esport", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("esport-tabs")

                switch tab {
                case .watch: watch
                case .calendar: calendar
                case .results: results
                case .players: players
                }
                newsShelf
            }.padding()
        }.background(hexaNavy).navigationTitle("Esport").navigationBarTitleDisplayMode(.inline)
        .refreshable { await news.refresh() }
    }

    private var watch: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("À l’affiche", systemImage: "sparkle").font(.title2.bold())
            eventCard(.crown)
            HStack {
                Link(destination: EsportEvent.twitch) { Label("Twitch officiel", systemImage: "play.rectangle") }
                Link(destination: EsportEvent.youtube) { Label("YouTube", systemImage: "play.circle") }
            }.buttonStyle(.bordered).tint(.mint)
            Text("Les chaînes officielles indiquent si une diffusion est en cours.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var calendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Le calendrier", systemImage: "calendar").font(.title2.bold())
            eventCard(.crown)
            Panel {
                Label("Le parcours du mondial", systemImage: "point.3.connected.trianglepath.dotted").font(.headline)
                phase("13 NOV.", "40 → 32", "Six manches pour établir le classement initial.")
                phase("14 NOV.", "32 → 8", "Éliminations successives jusqu’à la table finale.")
                phase("15 NOV.", "Finale", "Les huit qualifiés se disputent le titre.")
                Link("Règlement et calendrier du set", destination: EsportEvent.roadmap)
            }
            eventCard(.superbrawl)
            eventCard(.regional)
            Link("Planning officiel Compete TFT", destination: EsportEvent.schedule)
                .buttonStyle(.bordered)
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Résultats et rediffusions", systemImage: "medal").font(.title2.bold())
            Panel {
                Label("Superbrawl · tableaux officiels", systemImage: "list.number").font(.headline)
                sourceLink("EMEA", icon: "globe.europe.africa", url: URL(string: "https://competetft.com/en-US/tournament/117008552290488714/overview")!)
                sourceLink("AMER", icon: "globe.americas", url: URL(string: "https://competetft.com/en-US/tournament/117008531687591981/overview")!)
                sourceLink("APAC", icon: "globe.asia.australia", url: URL(string: "https://competetft.com/en-US/tournament/117008556467041885/overview")!)
            }
            Panel {
                Label("Dernier titre documenté dans Hexa", systemImage: "crown").font(.headline)
                Text("AUR Huanmie").font(.title2.bold())
                Text("Champion du monde · Space Gods · Chine").font(.subheadline).foregroundStyle(.secondary)
                sourceLink("Résultat et entretien Riot", icon: "newspaper", url: EsportEvent.huanmie)
                sourceLink("Rediffusions officielles", icon: "play.rectangle", url: EsportEvent.youtube)
            }
        }
    }

    private var players: some View {
        Panel {
            Label("CHINE · SPACE GODS", systemImage: "globe.asia.australia")
                .font(.caption.bold()).foregroundStyle(.mint)
            Text("AUR Huanmie").font(.title2.bold())
            HStack {
                DashboardMetric(title: "Titres internationaux", value: "3")
                DashboardMetric(title: "Titre mondial", value: "Set 17", accent: .mint)
            }
            Text("Riot recense trois titres internationaux, Reckoning, TFT Paris Open et Tactician’s Crown Space Gods.")
                .font(.subheadline).foregroundStyle(.secondary)
            Toggle("Suivre AUR Huanmie", isOn: $followHuanmie)
            sourceLink("Portrait et stratégie de la finale", icon: "person.text.rectangle", url: EsportEvent.huanmie)
        }
    }

    private var newsShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Actualités Riot", systemImage: "newspaper").font(.title3.bold())
            if let snapshot = news.esports {
                Text("Vérifiées le " + snapshot.checked.formatted()).font(.caption).foregroundStyle(.secondary)
                ForEach(snapshot.articles.prefix(6)) { article in
                    Panel { sourceLink(article.title, icon: "doc.text", url: article.url) }
                }
            }
            Link("Toutes les actualités esport", destination: URL(string: "https://teamfighttactics.leagueoflegends.com/fr-fr/news/esports/")!)
        }
    }

    private func eventCard(_ event: EsportEvent) -> some View {
        Panel {
            HStack {
                Badge(text: event.region, color: .mint)
                Spacer()
                Image(systemName: event.icon).font(.title2).foregroundStyle(hexaGold).accessibilityHidden(true)
            }
            Text(event.title).font(.title2.bold())
            Label(event.dates, systemImage: "calendar").font(.subheadline.bold()).foregroundStyle(hexaGold)
            Text(event.format).font(.subheadline).foregroundStyle(.secondary)
            if event.id == EsportEvent.crown.id {
                HStack {
                    DashboardMetric(title: "Tacticiens", value: "40")
                    DashboardMetric(title: "Dotation totale", value: "470 000 $", accent: .mint)
                }
            }
            sourceLink("Annonce officielle", icon: "newspaper", url: event.url)
        }
    }

    private func phase(_ date: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Badge(text: date, color: hexaGold)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func sourceLink(_ label: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Label(label, systemImage: icon)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption)
            }.font(.subheadline.weight(.semibold))
        }
    }
}

struct UltimateLibraryView: View {
    var body: some View {
        List {
            Section { HexaBrand() }
            Section("Explorer") {
                NavigationLink { EsportView() } label: { Label("Esport", systemImage: "trophy") }
                NavigationLink { CodexView() } label: { Label("Codex", systemImage: "books.vertical") }
                NavigationLink { BoardView() } label: { Label("Plateau personnel", systemImage: "hexagon") }
            }
            Section("Mes données et références") {
                NavigationLink { JournalView() } label: { Label("Journal manuel", systemImage: "book") }
                NavigationLink { SourcesView() } label: { Label("Sources", systemImage: "globe") }
                NavigationLink { ProviderDirectoryView() } label: { Label("Annuaire des fournisseurs", systemImage: "link") }
            }
        }.navigationTitle("Plus")
    }
}

struct ProviderDirectoryView: View {
    private let sites = [
        ("TFT Academy", "https://tftacademy.com"), ("TFTips", "https://tftips.app"),
        ("Sologesang · MetaTFT", "https://www.metatft.com/pro-comps"), ("TFT Flow", "https://tftflow.com"),
        ("TFT Codex", "https://tftcodex.com"), ("Tactics.tools", "https://tactics.tools"),
        ("MetaTFT", "https://www.metatft.com"), ("Mobalytics", "https://mobalytics.gg/tft"),
        ("Blitz", "https://blitz.gg/tft/comps"), ("TFT Ninja", "https://tft.ninja"),
        ("La Casita del TFT", "https://lacasitadeltft.com"), ("BunnyMuffins", "https://bunnymuffins.lol"),
        ("TFTable", "https://www.tftable.cc"), ("HexComps", "https://hexcomps.com"),
        ("TFT Handbook", "https://tfthandbook.com"), ("TFTraits", "https://tftraits.com")
    ]
    var body: some View {
        List {
            Section("Données natives") {
                Label("Blitz · catalogue historique", systemImage: "chart.bar")
                Label("CommunityDragon · Codex et révisions", systemImage: "books.vertical")
                Label("Riot · nouvelles officielles et tracker", systemImage: "person.text.rectangle")
            }
            Section("Consultation chez les fournisseurs") {
                ForEach(sites.indices, id: \.self) { index in Link(sites[index].0, destination: URL(string: sites[index].1)!) }
            }
        }.navigationTitle("Fournisseurs")
    }
}
