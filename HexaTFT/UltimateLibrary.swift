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
    let url: URL
    let past: Bool
    static let events: [Self] = [
        .init(id: "crown", title: "Tactician’s Crown · Enchanted Wilds", region: "Mondial", dates: "13–15 novembre 2026",
              format: "Finale mondiale. Les créneaux précis et les résultats sont à vérifier auprès de Riot.",
              url: URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/regional-finals-2026-everything-you-need-to-know/")!, past: false),
        .init(id: "superbrawl", title: "Tactician’s Superbrawl", region: "Mondial", dates: "6–8 novembre 2026",
              format: "Tournoi par équipes de quatre.",
              url: URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/tacticians-superbrawl-teams-dates-and-format/")!, past: true),
        .init(id: "regional", title: "Finales régionales Enchanted Wilds", region: "EMEA · AMER · APAC", dates: "23–25 octobre et 30 octobre–1 novembre 2026",
              format: "Qualifications régionales pour la finale mondiale.",
              url: URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/regional-finals-2026-everything-you-need-to-know/")!, past: true)
    ]
}

struct EsportView: View {
    @EnvironmentObject private var news: RiotNewsStore
    @State private var tab = "En direct"
    @AppStorage("hexa.follow.huanmie") private var followHuanmie = false
    var body: some View {
        List {
            Section {
                Picker("Esport", selection: $tab) {
                    ForEach(["En direct", "Calendrier", "Résultats", "Joueurs"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
            }
            switch tab {
            case "Calendrier":
                Section("Dates annoncées par Riot") {
                    ForEach(EsportEvent.events) { event in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.title).font(.headline)
                            Text(event.dates).foregroundStyle(hexaGold)
                            Text(event.region + " · " + event.format).font(.caption)
                            Link("Annonce officielle", destination: event.url)
                        }
                    }
                }
            case "Résultats":
                Section("Résultats et VOD") {
                    Text("Scores et classements structurés indisponibles. Les résultats publiés par Riot et les rediffusions sont accessibles ci-dessous.").font(.subheadline)
                    Link("Rediffusions officielles", destination: URL(string: "https://www.youtube.com/@playtft/streams")!)
                    Link("Compétitions et résultats Riot", destination: URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/")!)
                }
            case "Joueurs":
                Section("Joueurs documentés") {
                    LabeledContent("AUR Huanmie", value: "Chine")
                    Text("Champion du monde Space Gods, set 17.")
                    Toggle("Suivre AUR Huanmie", isOn: $followHuanmie)
                    Link("Portrait Riot", destination: URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/5-questions-with-aur-huanmie-the-space-gods-champion/")!)
                }
            default:
                Section("Diffusions officielles") {
                    Text("Vérifie le direct sur la chaîne officielle. Le calendrier seul ne confirme pas qu’une manche est en cours.").font(.subheadline)
                    Link("Teamfight Tactics sur Twitch", destination: URL(string: "https://www.twitch.tv/teamfighttactics")!)
                    Link("Teamfight Tactics sur YouTube", destination: URL(string: "https://www.youtube.com/@playtft/streams")!)
                }
            }
            Section("Actualités Riot") {
                if let snapshot = news.esports {
                    Text("Vérifié le \(snapshot.checked.formatted())").font(.caption).foregroundStyle(.secondary)
                    ForEach(snapshot.articles.prefix(12)) { article in Link(article.title, destination: article.url) }
                } else {
                    Text("Le fil d’actualités est momentanément indisponible.").font(.caption)
                }
                Link("Toutes les actualités esport", destination: URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/")!)
            }
        }.navigationTitle("Esport")
        .refreshable { await news.refresh() }
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
                Label("Blitz · compositions et statistiques", systemImage: "chart.bar")
                Label("CommunityDragon · Codex et révisions", systemImage: "books.vertical")
                Label("Riot · nouvelles officielles et tracker", systemImage: "person.text.rectangle")
            }
            Section("Consultation chez les fournisseurs") {
                ForEach(sites.indices, id: \.self) { index in Link(sites[index].0, destination: URL(string: sites[index].1)!) }
            }
        }.navigationTitle("Fournisseurs")
    }
}
