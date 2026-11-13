import SwiftUI
import Foundation

struct RiotArticle: Codable, Identifiable {
    let title: String
    let path: String
    var id: String { path }
    var patchNumber: String? {
        let prefix = "/en-us/news/game-updates/teamfight-tactics-patch-"
        guard path.hasPrefix(prefix) else { return nil }
        let version = path.dropFirst(prefix.count).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard version.range(of: #"^\d{1,2}-\d{1,2}$"#, options: .regularExpression) != nil else { return nil }
        return version.replacingOccurrences(of: "-", with: ".")
    }
    var url: URL { URL(string: "https://teamfighttactics.leagueoflegends.com" + path)! }
}
struct RiotNewsSnapshot: Codable {
    let articles: [RiotArticle]
    let checked: Date
}
@MainActor final class RiotNewsStore: ObservableObject {
    @Published private(set) var esports: RiotNewsSnapshot?
    @Published private(set) var patches: RiotNewsSnapshot?
    @Published private(set) var competeSchedule: CompeteSchedule?
    private let directory = URL.applicationSupportDirectory.appendingPathComponent("HexaTFT")
    private var lastAttempt: Date?
    private var refreshing = false
    init() {
        esports = load("esports")
        patches = load("game-updates")
        let file = directory.appendingPathComponent("compete-calendar.json")
        if let data = try? Data(contentsOf: file) { competeSchedule = try? JSONDecoder().decode(CompeteSchedule.self, from: data) }
    }
    func refresh() async {
        guard !refreshing, lastAttempt.map({ Date().timeIntervalSince($0) >= 300 }) ?? true else { return }
        refreshing = true; lastAttempt = Date()
        defer { refreshing = false }
        async let esportsResult = Self.fetch("esports")
        async let patchResult = Self.fetch("game-updates")
        async let calendarResult = CompeteSchedule.fetch()
        if let result = await calendarResult {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? JSONEncoder().encode(result).write(to: directory.appendingPathComponent("compete-calendar.json"), options: .atomic)
            competeSchedule = result
        }
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
    let end: Date
    let format: String
    let icon: String
    let url: URL

    static let crown = Self(id: "crown", title: "Tactician’s Crown", region: "Mondial", dates: "13–15 novembre 2026", end: finish("2026-11-16T00:00:00+01:00"),
        format: "La finale mondiale du set 18 réunit 40 tacticiens en trois journées.",
        icon: "crown", url: URL(string: "https://competetft.com/en-US/tournament/116918001686340951/overview")!)
    static let superbrawl = Self(id: "superbrawl", title: "Tactician’s Superbrawl", region: "EMEA · AMER · APAC", dates: "6–8 novembre 2026", end: finish("2026-11-09T00:00:00+01:00"),
        format: "Tournoi par équipes de quatre, avec une finale en cinq manches maximum.",
        icon: "person.3.sequence", url: URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/tacticians-superbrawl-teams-dates-and-format/")!)
    static let regional = Self(id: "regional", title: "Finales régionales", region: "EMEA · AMER · APAC", dates: "23–25 oct. et 30 oct.–1 nov. 2026", end: finish("2026-11-02T00:00:00+01:00"),
        format: "Deux week-ends de qualification pour le mondial, avec 64 tacticiens dans chaque région.",
        icon: "globe.europe.africa", url: URL(string: "https://teamfighttactics.leagueoflegends.com/fr-fr/news/esports/regional-finals-2026-everything-you-need-to-know/")!)

    static let vegas = Self(id: "vegas", title: "TFT Vegas Open", region: "LAN · Las Vegas", dates: "11–13 décembre 2026", end: finish("2026-12-14T00:00:00-08:00"),
        format: "Open du set 19. Jusqu’à 1 024 participants dans le tournoi principal.",
        icon: "ticket", url: URL(string: "https://teamfighttactics.leagueoflegends.com/fr-fr/news/esports/tft-vegas-open-2026-competitor-info/")!)
    static let emeaResults = URL(string: "https://competetft.com/en-US/tournament/116912974691526392/overview")!
    static let ladder = URL(string: "https://tactics.tools/leaderboards")!
    static let standings = URL(string: "https://tftlobby.gg/")!
    static let events = [regional, superbrawl, crown, vegas]

    private static func finish(_ instant: String) -> Date {
        ISO8601DateFormatter().date(from: instant) ?? .distantPast
    }
    static let roadmap = URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/compete-in-enchanted-wilds/")!
    static let schedule = URL(string: "https://competetft.com/schedule")!
    static let twitch = URL(string: "https://www.twitch.tv/teamfighttactics")!
    static let youtube = URL(string: "https://www.youtube.com/@playtft/streams")!
    static let huanmie = URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/esports/5-questions-with-aur-huanmie-the-space-gods-champion/")!
    static let crownTimes = URL(string: "https://x.com/CompeteTFT/status/2119777028778189184")!
    static let crownQualifiers = URL(string: "https://competetft.com/en-US/tournament/116918001686340951/qualification/overview")!
    static let crownVideo = URL(string: "https://www.youtube.com/watch?v=hBNyo1jNnUs")!
    static let superbrawlWinners = URL(string: "https://x.com/CompeteTFT/status/2119882720218095836")!
    static let emeaBoards = URL(string: "https://bit.ly/S18EMEARFCOMPS")!
    static let amerBoards = URL(string: "https://bit.ly/s18amertpcdata")!
}

struct EsportView: View {
    @EnvironmentObject private var news: RiotNewsStore
    @State private var tab: Tab = .watch
    @AppStorage("hexa.follow.huanmie") private var followHuanmie = false
    @AppStorage("hexa.esport.followedPlayers") private var followedPlayers = ""
    @State private var playerSection: PlayerSection = .tournament
    @State private var qualifiersRegion: String?
    @State private var showMilestones = false

    private enum PlayerSection: String, CaseIterable {
        case tournament = "Tournois", ladder = "Ladder", clubs = "Clubs FR", followed = "Suivis"
    }

    enum Tab: String, CaseIterable {
        case watch = "En direct", calendar = "Calendrier", results = "Résultats", players = "Joueurs"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                FeatureBanner(eyebrow: "HEXA ARENA", title: "TFT Esport",
                              detail: "Calendrier, résultats et joueurs à suivre", icon: "trophy")
                Picker("Esport", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("esport-tabs")

                switch tab {
                case .watch: watch
                case .calendar: calendar
                case .results: results
                case .players: players
                }
                if tab == .watch { newsShelf }
            }.padding()
        }.background(hexaNavy).navigationTitle("Esport").navigationBarTitleDisplayMode(.inline)
        .refreshable { await news.refresh() }
    }

    private var watch: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("À l’affiche", systemImage: "sparkle").font(.title2.bold())
            if let next = EsportEvent.events.first(where: { $0.end > .now }) {
                eventCard(next)
                if next.id == EsportEvent.crown.id {
                    Button { tab = .calendar } label: {
                        Label("Programme du Mondial · 13 h à Paris", systemImage: "clock")
                    }.buttonStyle(.bordered)
                }
            }
            HStack {
                Link(destination: EsportEvent.twitch) { Label("Twitch officiel", systemImage: "play.rectangle") }
                Link(destination: EsportEvent.youtube) { Label("YouTube", systemImage: "play.circle") }
            }.buttonStyle(.bordered).tint(.mint)
            Text("Diffusion et scores à vérifier sur les chaînes et tableaux officiels.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var calendar: some View {
        let upcoming = EsportEvent.events.filter { $0.end > .now }
        let finished = EsportEvent.events.filter { $0.end <= .now }.reversed()
        return VStack(alignment: .leading, spacing: 12) {
            Label("À venir et en cours", systemImage: "calendar").font(.title2.bold())
            if upcoming.isEmpty {
                Text("Consulte le calendrier officiel pour les prochaines dates.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(upcoming) { event in
                eventCard(event)
                if event.id == EsportEvent.crown.id { crownSchedule }
            }
            if let schedule = news.competeSchedule {
                officialCalendar(schedule)
            }
            Label("Événements terminés", systemImage: "checkmark.circle").font(.title3.bold())
            ForEach(finished) { event in
                eventCard(event)
                if event.id == EsportEvent.crown.id { crownSchedule }
            }
            Link("Planning officiel Compete TFT", destination: EsportEvent.schedule)
                .buttonStyle(.bordered)
        }
    }

    private var crownSchedule: some View {
        Panel {
            Label("Le parcours du mondial", systemImage: "point.3.connected.trianglepath.dotted").font(.headline)
            Text("13 h chaque jour · heure de Paris").font(.subheadline.bold()).foregroundStyle(.mint)
            phase("13 NOV.", "40 → 32", "Six manches. Les groupes changent toutes les deux parties.")
            phase("14 NOV.", "32 → 8", "Sept manches. Quatre places directes puis quatre places au repêchage.")
            phase("15 NOV.", "Finale à huit", "Format Checkmate. Atteindre 20 points, puis remporter une manche.")
            sourceLink("Horaires annoncés par Compete TFT", icon: "clock", url: EsportEvent.crownTimes)
            sourceLink("Format en vidéo", icon: "play.rectangle", url: EsportEvent.crownVideo)
        }
    }

    private func officialCalendar(_ schedule: CompeteSchedule) -> some View {
        let visible = schedule.entries.filter {
            $0.title != "Tactician's Crown" && (showMilestones || !$0.isMilestone)
        }
        let upcoming = visible.filter { $0.end > .now }
        let past = visible.filter { $0.end <= .now }.reversed()
        return Panel {
            Label("Calendrier Compete TFT", systemImage: "calendar.badge.clock").font(.headline)
            Text("Vérifié le " + schedule.checked.formatted(date: .abbreviated, time: .shortened) + " · heure de Paris")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Afficher inscriptions et relevés", isOn: $showMilestones).font(.subheadline)
            ForEach(upcoming) { entry in
                phase(entry.displayDate, entry.displayTitle, entry.isMilestone ? "Jalon" : "Compétition")
            }
            DisclosureGroup("Historique du circuit") {
                ForEach(past) { entry in
                    phase(entry.displayDate, entry.displayTitle, entry.isMilestone ? "Jalon" : "Compétition").padding(.top, 8)
                }
            }
            sourceLink("Calendrier publié par Riot", icon: "calendar", url: CompeteSchedule.source)
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Résultats et rediffusions", systemImage: "medal").font(.title2.bold())
            Panel {
                Label("Finales régionales EMEA", systemImage: "trophy").font(.headline)
                ForEach(EsportPlayer.emea) { player in playerRow(player) }
                sourceLink("Tableau officiel EMEA", icon: "list.number", url: EsportEvent.emeaResults)
            }
            Panel {
                Label("Superbrawl · tableaux officiels", systemImage: "list.number").font(.headline)
                phase("EMEA", "Team AWOO", "TheoDokhy · ToonTV · EtreInfame · Voltariux")
                phase("AMER", "Team Los Capos", "santt27 · sodinacho · AbyssVGC · DominusTFT")
                sourceLink("Annonce des vainqueurs", icon: "trophy", url: EsportEvent.superbrawlWinners)
                sourceLink("EMEA", icon: "globe.europe.africa", url: URL(string: "https://competetft.com/en-US/tournament/117008552290488714/overview")!)
                sourceLink("AMER", icon: "globe.americas", url: URL(string: "https://competetft.com/en-US/tournament/117008531687591981/overview")!)
                sourceLink("APAC", icon: "globe.asia.australia", url: URL(string: "https://competetft.com/en-US/tournament/117008556467041885/overview")!)
            }
            Panel {
                Label("Compositions de compétition", systemImage: "square.stack.3d.up").font(.headline)
                Text("Relevés des finales régionales partagés par Compete TFT.").font(.caption).foregroundStyle(.secondary)
                sourceLink("Plateaux EMEA · semaine 2", icon: "tablecells", url: EsportEvent.emeaBoards)
                sourceLink("Plateaux AMER · semaine 2", icon: "tablecells", url: EsportEvent.amerBoards)
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
        VStack(alignment: .leading, spacing: 12) {
            Picker("Liste des joueurs", selection: $playerSection) {
                ForEach(PlayerSection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("esport-player-sections")
            switch playerSection {
            case .tournament:
                Panel {
                    Label("Qualifiés pour le Mondial", systemImage: "crown.fill").font(.headline).foregroundStyle(hexaGold)
                    HStack {
                        Text("Sélection Compete TFT · 10 nov. 2026").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Picker("Région", selection: $qualifiersRegion) {
                            Text("Toutes").tag(nil as String?)
                            ForEach(["EMEA", "AMER", "APAC", "CN"], id: \.self) { Text($0).tag(Optional($0)) }
                        }.labelsHidden()
                    }
                    ForEach(EsportPlayer.qualifiers.filter { qualifiersRegion == nil || $0.region == qualifiersRegion }) { player in
                        playerRow(player)
                    }
                    sourceLink("Liste officielle des qualifiés", icon: "person.3", url: EsportEvent.crownQualifiers)
                }
                Panel {
                    Label("Finale régionale EMEA", systemImage: "medal").font(.headline)
                    Text("Classement final · 1er novembre 2026").font(.caption).foregroundStyle(.secondary)
                    ForEach(EsportPlayer.emea) { player in playerRow(player) }
                    sourceLink("Voir le tableau officiel", icon: "list.number", url: EsportEvent.emeaResults)
                    sourceLink("Détail des manches sur TFT Lobby", icon: "tablecells", url: EsportEvent.standings)
                }
                Panel {
                    Label("Champion du monde du set 17", systemImage: "crown").font(.headline)
                    playerRow(EsportPlayer.huanmie)
                }
            case .ladder:
                Panel {
                    Label("Ladder mondial TFT", systemImage: "chart.line.uptrend.xyaxis").font(.headline)
                    Text("Relevé du 10 novembre 2026 · file classée").font(.caption).foregroundStyle(.secondary)
                    ForEach(EsportPlayer.ladder) { player in playerRow(player) }
                    sourceLink("Classement mondial actualisé", icon: "arrow.up.right.square", url: EsportEvent.ladder)
                    sourceLink("Classement EUW actualisé", icon: "globe.europe.africa", url: URL(string: "https://tactics.tools/leaderboards/euw")!)
                }
            case .clubs:
                ForEach(EsportClub.french) { club in
                    Panel {
                        Label(club.name, systemImage: "flag.fill").font(.title3.bold()).foregroundStyle(hexaGold)
                        Text(club.context).font(.caption).foregroundStyle(.secondary)
                        ForEach(club.players) { player in playerRow(player) }
                        sourceLink("Effectif publié par le club", icon: "person.3", url: club.source)
                    }
                }
            case .followed:
                let ids = Set(followedPlayers.split(separator: "|").map(String.init))
                let selected = EsportPlayer.directory.filter { ids.contains($0.id) || ($0.id == "huanmie" && followHuanmie) }
                if selected.isEmpty {
                    ContentUnavailableView("Aucun joueur suivi", systemImage: "star",
                                           description: Text("Touche l’étoile d’un joueur pour retrouver sa fiche ici."))
                }
                ForEach(selected) { player in Panel { playerRow(player) } }
            }
        }
    }

    private func playerRow(_ player: EsportPlayer) -> some View {
        HStack(spacing: 10) {
            if let rank = player.rank { Badge(text: "#\(rank)", color: rank == 1 ? hexaGold : .mint) }
            NavigationLink { EsportPlayerDetail(player: player) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name).font(.subheadline.bold()).foregroundStyle(.primary)
                    Text(player.detail).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            let followed = followedPlayers.split(separator: "|").contains(Substring(player.id)) || (player.id == "huanmie" && followHuanmie)
            Button {
                var ids = Set(followedPlayers.split(separator: "|").map(String.init))
                if followed { ids.remove(player.id) } else { ids.insert(player.id) }
                if player.id == "huanmie" { followHuanmie = !followed }
                followedPlayers = ids.sorted().joined(separator: "|")
            } label: {
                Image(systemName: followed ? "star.fill" : "star")
                    .frame(minWidth: 44, minHeight: 44).foregroundStyle(hexaGold)
            }.buttonStyle(.plain).accessibilityLabel((followed ? "Ne plus suivre " : "Suivre ") + player.name)
        }
        .padding(.vertical, 3)
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

struct EsportPlayer: Identifiable {
    let id: String
    let name: String
    let detail: String
    var rank: Int? = nil
    var url: URL? = nil
    var region: String? = nil

    static let coco = Self(id: "coco", name: "L3S Coco", detail: "Gentle Mates · France",
                           url: URL(string: "https://www.gentlemates.com/en/esports/player/L3SCOCO"))
    static let bensac = Self(id: "bensac", name: "Bensac", detail: "Mihos eSport · France",
                             url: URL(string: "https://mihosesport.com/"))
    static let huanmie = Self(id: "huanmie", name: "AUR Huanmie", detail: "Champion du monde · Set 17", url: EsportEvent.huanmie, region: "CN")
    static let emea: [Self] = [
        .init(id: coco.id, name: coco.name, detail: "Gentle Mates · 34 points", rank: 1, url: coco.url),
        .init(id: bensac.id, name: bensac.name, detail: "Mihos eSport · 32 points", rank: 2, url: bensac.url),
        .init(id: "yakumo", name: "Yakumo", detail: "33 points · Checkmate", rank: 3),
        .init(id: "oskuu", name: "oskuu", detail: "26 points · Checkmate", rank: 4),
        .init(id: "cynarr", name: "Cynarr", detail: "28 points · Checkmate", rank: 5),
        .init(id: "whyyoumadpro", name: "whyyoumadpro", detail: "24 points", rank: 6),
        .init(id: "etre-infame", name: "Etre Infame", detail: "19 points", rank: 7),
        .init(id: "snoodyboo", name: "EPSI Snoodyboo", detail: "20 points", rank: 8)
    ]
    static let ladder: [Self] = [
        .init(id: "7yearsold", name: "7YearsOld", detail: "SEA · 1 968 LP", rank: 1),
        .init(id: "geolo69", name: "geolo69", detail: "EUNE · 1 949 LP", rank: 2),
        .init(id: "kurapika", name: "Kurapika", detail: "LAN · 1 936 LP", rank: 3),
        .init(id: "araye", name: "ARaye", detail: "SEA · 1 919 LP", rank: 4),
        .init(id: "kr-102", name: "102", detail: "KR · 1 916 LP", rank: 5),
        .init(id: "whyyoumadpro", name: "whyyoumadpro", detail: "EUW · 1 894 LP", rank: 6),
        .init(id: "summertimer", name: "ZETA summertimer", detail: "JP · 1 868 LP", rank: 7),
        .init(id: "asta1", name: "Asta1 nè", detail: "VN · 1 856 LP", rank: 8),
        .init(id: "lelouch45123", name: "LELOUCH45123", detail: "LAN · 1 841 LP", rank: 9),
        .init(id: "zounderkite", name: "Zounderkite", detail: "TR · 1 839 LP", rank: 10)
    ]

    static let qualifiers: [Self] = {
        func group(_ region: String, _ path: String, _ players: [(String, String)]) -> [Self] {
            players.map { id, name in Self(id: id, name: name, detail: region + " · " + path, region: region) }
        }
        return group("EMEA", "Finales régionales", [
            ("coco", "L3S Coco"), ("yakumo", "Yakumo"), ("cynarr", "Cynarr"), ("oskuu", "oskuu"), ("whyyoumadpro", "whyyoumadpro")
        ]) + group("EMEA", "TFT Pro Circuit", [
            ("bensac", "Bensac"), ("zykoo", "MIH ZyK0o"), ("skipaeus", "Skipaeus")
        ]) + group("AMER", "Finales régionales", [
            ("broseph", "Broseph"), ("bopster", "bopster"), ("upsetmax", "FL Upsetmax"), ("ego", "TFTLAB ego"), ("deleted", "MJS Deleted")
        ]) + group("AMER", "TFT Pro Circuit", [
            ("wasian", "ACAD wasian"), ("dishsoap", "ACAD Dishsoap"), ("wigwugg", "FL wigwugg"), ("chunington", "FL Chunington"), ("cambulee", "FL Cambulee")
        ]) + group("APAC", "Finales régionales", [
            ("jazlatte", "ROC JazLatte"), ("aq1h", "FW AQ1H"), ("milo", "Milo"), ("pigpig", "pigpig"),
            ("title", "ZETA title"), ("maris", "Maris"), ("iceemperoz", "iCeEmperoz")
        ]) + group("APAC", "TFT Pro Circuit", [
            ("seoill", "seoill"), ("withoutyou", "WithoutYou"), ("steppy", "steppy"), ("ironbog", "FW Iron Bog")
        ]) + group("CN", "TFT Pro Circuit", [("hanxing", "YSG Hanxing")])
    }()

    static var directory: [Self] {
        var seen = Set<String>()
        return ([huanmie] + EsportClub.french.flatMap(\.players) + qualifiers + emea + ladder).filter { seen.insert($0.id).inserted }
    }
}

private struct EsportPlayerDetail: View {
    let player: EsportPlayer
    private var club: EsportClub? { EsportClub.french.first { $0.players.contains { $0.id == player.id } } }
    private var qualification: EsportPlayer? { EsportPlayer.qualifiers.first { $0.id == player.id } }
    private var result: EsportPlayer? { EsportPlayer.emea.first { $0.id == player.id } }
    private var ladder: EsportPlayer? { EsportPlayer.ladder.first { $0.id == player.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FeatureBanner(eyebrow: "JOUEUR TFT", title: player.name, detail: club?.name ?? player.detail,
                              icon: "person.crop.rectangle", accent: .mint)
                if let qualification {
                    Panel {
                        Label("Tactician’s Crown · Set 18", systemImage: "crown.fill").font(.headline)
                        Text(qualification.detail).font(.subheadline)
                        Link("Voir la liste officielle", destination: EsportEvent.crownQualifiers)
                    }
                }
                if let result {
                    Panel {
                        Label("Finales régionales EMEA · 1er novembre 2026", systemImage: "trophy").font(.headline)
                        if let rank = result.rank { Badge(text: "#\(rank)", color: hexaGold) }
                        Text(result.detail).font(.subheadline)
                        Link("Tableau de la finale", destination: EsportEvent.emeaResults)
                    }
                }
                if let ladder, let rank = ladder.rank {
                    Panel {
                        Label("Ladder mondial · 10 novembre 2026", systemImage: "list.number").font(.headline)
                        Text("#\(rank) · \(ladder.detail)").font(.subheadline)
                        Link("Ladder sur Tactics.Tools", destination: EsportEvent.ladder)
                    }
                }
                if let club {
                    Panel {
                        Label(club.name, systemImage: "flag.fill").font(.headline)
                        Text(club.context).font(.subheadline).foregroundStyle(.secondary)
                        Link("Effectif du club", destination: club.source)
                        if club.name == "Gentle Mates" { Link("Replays de l’équipe TFT", destination: club.source) }
                    }
                }
                if let url = player.url ?? club?.players.first(where: { $0.id == player.id })?.url {
                    Link("Profil officiel", destination: url).buttonStyle(.bordered)
                }
            }.padding()
        }.background(hexaNavy).navigationTitle("Joueur").navigationBarTitleDisplayMode(.inline)
    }
}

struct EsportClub: Identifiable {
    let name: String
    let context: String
    let players: [EsportPlayer]
    let source: URL
    var id: String { name }

    static let french: [Self] = [
        .init(name: "Gentle Mates", context: "Section TFT · France", players: [
            .coco, .init(id: "jedusor", name: "Jedusor", detail: "France", url: URL(string: "https://www.gentlemates.com/en/esports/player/jedusor"))
        ], source: URL(string: "https://www.gentlemates.com/esports?game=teamfight-tactics")!),
        .init(name: "Mihos eSport", context: "Section TFT · France", players: [.bensac],
              source: URL(string: "https://mihosesport.com/")!),
        .init(name: "Team Vitality", context: "Club français · joueurs AMER affichés par Vitality", players: [
            .init(id: "setsuko", name: "setsuko", detail: "AMER", url: URL(string: "https://vitality.gg/en/pages/athletes/setsuko")),
            .init(id: "k3soju", name: "k3soju", detail: "AMER", url: URL(string: "https://vitality.gg/en/pages/athletes/k3soju")),
            .init(id: "milk", name: "Milk", detail: "AMER", url: URL(string: "https://vitality.gg/en/pages/athletes/milk")),
            .init(id: "prestivent", name: "Prestivent", detail: "AMER", url: URL(string: "https://vitality.gg/en/pages/athletes/prestivent"))
        ], source: URL(string: "https://vitality.gg/en/pages/athletes/setsuko")!)
    ]
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
            }
        }.navigationTitle("Plus")
    }
}
