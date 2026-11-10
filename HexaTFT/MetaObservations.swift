import SwiftUI

enum MetaSort: String, CaseIterable {
    case top4 = "Top 4", top1 = "Top 1", average = "Moyenne", discovery = "Découverte"

    func score(average: Double, top4: Double, top1: Double?) -> Double {
        switch self {
        case .top4, .discovery: return top4
        case .top1: return top1 ?? -.infinity
        case .average: return -average
        }
    }

    func guides(_ comps: [MetaComp], score: (MetaComp) -> Double) -> [MetaComp] {
        comps.sorted { first, second in
            let left = score(first), right = score(second)
            return left == right ? first.id < second.id : left > right
        }
    }

    func readings(_ entries: [MetaObservation]) -> [MetaObservation] {
        let sorted = entries.sorted { first, second in
            let left = score(average: first.average, top4: first.top4, top1: first.top1)
            let right = score(average: second.average, top4: second.top4, top1: second.top1)
            if left != right { return left > right }
            if first.average != second.average { return first.average < second.average }
            return first.id < second.id
        }
        guard self == .discovery else { return sorted }
        var counts: [MetaObservation.Provider: Int] = [:]
        let positions = sorted.enumerated().map { index, entry in
            let round = counts[entry.provider, default: 0]
            counts[entry.provider] = round + 1
            return (round, index, entry)
        }
        return positions.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map { $0.2 }
    }
}

struct MetaObservation: Codable, Identifiable {
    enum Provider: String, Codable, CaseIterable, Identifiable {
        case codex = "TFT Codex"
        case tactics = "Tactics.Tools"
        case metastats = "MetaStats.gg"

        var id: String { rawValue }
        var context: String {
            switch self {
            case .codex: "Classé Diamant+ · 5–10 nov. 2026"
            case .tactics: "Classé Maître+ · consulté le 10 nov. 2026"
            case .metastats: "Diamant+ · filtre 3 jours · toutes régions · consulté le 10 nov. 2026"
            }
        }
        var hosts: Set<String> {
            switch self {
            case .codex: ["tftcodex.com", "www.tftcodex.com"]
            case .tactics: ["tactics.tools", "www.tactics.tools"]
            case .metastats: ["metastats.gg", "www.metastats.gg"]
            }
        }
        var color: Color {
            switch self {
            case .codex: hexaGold
            case .tactics: .mint
            case .metastats: .cyan
            }
        }
    }

    let id: String
    let provider: Provider
    let title: String
    let champions: [String]
    let average: Double
    let top4: Double
    var top1: Double? = nil
    var games: Int? = nil
    let source: URL
    var scope: String? = nil

    static let readings: [Self] = [
        .init(id: "codex-roncier", provider: .codex, title: "Roncier Jungle", champions: ["DA_Brambleback18", "DA_Krug18", "DA_18_ElderDragon"],
              average: 4.19, top4: 0.557, games: 91_162, source: URL(string: "https://tftcodex.com/comps/riftbeast-brambleback.html")!),
        .init(id: "codex-draven", provider: .codex, title: "Draven · Maokai Sylvestre", champions: ["DA_Draven18", "DA_18_Maokai", "DA_18_Ezreal"],
              average: 4.21, top4: 0.526, games: 50_483, source: URL(string: "https://tftcodex.com/comps/elderwood-draven.html")!),
        .init(id: "codex-yunara", provider: .codex, title: "Yunara · Sejuani Solaire", champions: ["DA_18_Yunara", "DA_18_Sejuani", "DA_Karma18"],
              average: 4.38, top4: 0.530, top1: 0.135, games: 71_647, source: URL(string: "https://tftcodex.com/comps/solar-yunara.html")!),
        .init(id: "tactics-ezreal", provider: .tactics, title: "Ezreal Sylvestre", champions: ["DA_18_Ezreal", "DA_18_Hecarim", "DA_18_LeBlanc"],
              average: 4.21, top4: 0.541, top1: 0.191, source: tacticsURL),
        .init(id: "tactics-morgana", provider: .tactics, title: "Morgana · Sentinelle", champions: ["DA_18_Morgana", "DA_Sentinel18", "DA_18_Sett"],
              average: 4.24, top4: 0.545, top1: 0.179, source: tacticsURL),
        .init(id: "tactics-yi", provider: .tactics, title: "Maître Yi · Vi Fleur spirituelle", champions: ["DA_18_MasterYi_AD", "DA_Vi18", "DA_18_Yorick"],
              average: 4.27, top4: 0.549, top1: 0.113, source: tacticsURL),
        .init(id: "metastats-raptor", provider: .metastats, title: "Maman Raptor · Zyra", champions: ["DA_CrimsonRaptor18", "DA_18_Zyra", "DA_18_Hecarim"],
              average: 4.17, top4: 0.57, top1: 0.10, games: 6_330, source: metaStats("summoner-mama-beak")),
        .init(id: "metastats-teemo", provider: .metastats, title: "Teemo · LeBlanc Incantateur", champions: ["DA_18_Teemo", "DA_18_LeBlanc", "DA_18_Alistar"],
              average: 4.37, top4: 0.55, top1: 0.06, games: 19_262, source: metaStats("invoker-teemo")),
        .init(id: "codex-veigar", provider: .codex, title: "Veigar · Sylvestre", champions: ["DA_18_Veigar", "DA_18_Ornn", "DA_18_Alistar"],
              average: 4.37, top4: 0.525, top1: 0.122, games: 50_037, source: codexURL),
        .init(id: "codex-azir", provider: .codex, title: "Rammus · Azir Ami de la forêt", champions: ["DA_18_Rammus", "DA_18_Azir", "DA_18_Teemo"],
              average: 4.28, top4: 0.546, top1: 0.122, games: 21_212, source: codexURL),
        .init(id: "codex-ahri-zyra", provider: .codex, title: "Ahri · Zyra avec Lillia", champions: ["DA_18_Ahri", "DA_18_Zyra", "DA_18_Lillia"],
              average: 4.67, top4: 0.475, top1: 0.091, games: 51_075, source: codexURL),
        .init(id: "codex-aphelios", provider: .codex, title: "Aphelios · Nidalee Primitif", champions: ["DA_18_Aphelios", "DA_Nidalee18_AP", "DA_Vi18"],
              average: 4.68, top4: 0.481, top1: 0.048, games: 42_399, source: codexURL),
        .init(id: "codex-soraka", provider: .codex, title: "Soraka · Malphite Exécuteur", champions: ["DA_18_Soraka", "DA_18_Malphite", "DA_18_Azir"],
              average: 4.64, top4: 0.481, top1: 0.083, games: 35_013, source: codexURL),
        .init(id: "codex-sivir", provider: .codex, title: "Sivir · Ashe Primitif", champions: ["DA_18_Sivir", "DA_18_Ashe", "DA_Vi18"],
              average: 4.49, top4: 0.499, top1: 0.143, games: 22_769, source: codexURL),
        .init(id: "codex-cassiopeia", provider: .codex, title: "Cassiopeia · Fiddlesticks Défenseur", champions: ["DA_18_Cassiopeia", "DA_Fiddlesticks18", "DA_18_Rammus"],
              average: 4.51, top4: 0.50, top1: 0.089, games: 16_862, source: codexURL),
        .init(id: "codex-tristana", provider: .codex, title: "Tristana Fæ", champions: ["DA_18_Tristana", "DA_18_Lillia", "DA_18_Rakan"],
              average: 4.77, top4: 0.443, top1: 0.122, games: 19_565, source: codexURL),
        .init(id: "tactics-ezreal-aphelios", provider: .tactics, title: "Ezreal · Aphelios Sylvestre", champions: ["DA_18_Ezreal", "DA_18_Aphelios", "DA_18_Hecarim"],
              average: 4.33, top4: 0.536, top1: 0.128, source: tacticsURL)
    ]

    private static let codexURL = URL(string: "https://tftcodex.com/comps/")!
    private static let tacticsURL = URL(string: "https://tactics.tools/team-compositions/top")!
    private static func metaStats(_ path: String) -> URL {
        URL(string: "https://www.metastats.gg/en/tft/comps/" + path + "?bucket=diamond_plus&days=3&region=all")!
    }

    var relatedGuide: String? {
        switch id {
        case "codex-ahri-zyra": "hexa-ahri-zyra"
        case "codex-yunara": "hexa-yunara-solaire"
        case "tactics-yi": "hexa-yi-vi"
        case "metastats-teemo": "hexa-teemo-leblanc"
        default: nil
        }
    }

    func matches(_ query: String) -> Bool {
        query.isEmpty || (title + " " + provider.rawValue).localizedStandardContains(query)
    }
}

struct MetaRadarSnapshot: Codable {
    let patch: String
    let build: String
    let set: String
    let retrievedAt: Date
    var readings: [MetaObservation]
    var nextCursor: String? = nil

    static let bundled = Self(patch: "18.6", build: "16.22", set: "18",
                             retrievedAt: Date(timeIntervalSince1970: 1794302220),
                             readings: MetaObservation.readings)

    var label: String {
        "Relevé " + patch + " · " + retrievedAt.formatted(.dateTime.day().month(.abbreviated).year())
    }

    func matches(_ reference: ReferenceData?) -> Bool {
        guard let reference else { return false }
        return reference.entries.first?.set == set &&
            (reference.version == build || reference.version.hasPrefix(build + "."))
    }

    func merging(_ page: Self, after cursor: String) -> Self? {
        guard cursor == nextCursor, patch == page.patch, build == page.build,
              set == page.set, retrievedAt == page.retrievedAt else { return nil }
        var result = self
        var seen = Set(readings.map(\.id))
        result.readings.append(contentsOf: page.readings.filter { seen.insert($0.id).inserted })
        result.nextCursor = page.nextCursor == cursor ? nil : page.nextCursor
        return result
    }

    func isValid(for reference: ReferenceData?, patch expectedPatch: String?) -> Bool {
        guard matches(reference), expectedPatch == nil || expectedPatch == patch,
              patch.range(of: #"^\d{1,2}\.\d{1,2}$"#, options: .regularExpression) != nil,
              !readings.isEmpty, Set(readings.map(\.id)).count == readings.count,
              nextCursor.map({ !$0.isEmpty && $0.utf8.count <= 512 }) != false else { return false }
        let champions = Set(reference?.entries.filter { $0.kind == "champion" }.map(\.id) ?? [])
        return readings.allSatisfy { reading in
            !reading.title.isEmpty && reading.title.count <= 100 && !reading.id.isEmpty &&
            reading.scope.map { !$0.isEmpty && $0.count <= 150 } == true &&
            (1...8).contains(reading.average) && (0...1).contains(reading.top4) &&
            reading.top1.map { (0...reading.top4).contains($0) } != false &&
            reading.games.map { $0 > 0 } != false && reading.champions.count <= 5 &&
            reading.champions.allSatisfy { champions.contains("champion:" + $0) } &&
            reading.source.scheme == "https" && reading.source.user == nil && reading.source.password == nil &&
            reading.source.host.map { reading.provider.hosts.contains($0) } == true
        }
    }
}

struct MetaObservationCard: View {
    let entry: MetaObservation
    let reference: ReferenceData?

    var body: some View {
        Panel {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.provider.rawValue).font(.caption.bold()).foregroundStyle(entry.provider.color)
                    Text(entry.title).font(.headline)
                    Text(entry.scope ?? entry.provider.context).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(entry.provider.color)
            }
            if let reference {
                HStack(spacing: 6) {
                    ForEach(entry.champions, id: \.self) { key in
                        if let champion = reference.entries.first(where: { $0.id == "champion:" + key }) {
                            EntryIcon(entry: champion, size: 32)
                        }
                    }
                }
            }
            MetaObservationMetrics(entry: entry)
        }
    }
}

struct MetaObservationMetrics: View {
    let entry: MetaObservation
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { metrics }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) { metrics }
        }
    }
    @ViewBuilder private var metrics: some View {
        DashboardMetric(title: "Moyenne", value: entry.average.formatted(.number.precision(.fractionLength(2))))
        DashboardMetric(title: "Top 4", value: entry.top4.formatted(.percent.precision(.fractionLength(1))), accent: .mint)
        if let top1 = entry.top1 { DashboardMetric(title: "Top 1", value: top1.formatted(.percent.precision(.fractionLength(1)))) }
        if let games = entry.games { DashboardMetric(title: "Plateaux", value: games.formatted()) }
    }
}
