import SwiftUI

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
              average: 4.37, top4: 0.55, top1: 0.06, games: 19_262, source: metaStats("invoker-teemo"))
    ]

    private static let tacticsURL = URL(string: "https://tactics.tools/team-compositions/top")!
    private static func metaStats(_ path: String) -> URL {
        URL(string: "https://www.metastats.gg/en/tft/comps/" + path + "?bucket=diamond_plus&days=3&region=all")!
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
    let readings: [MetaObservation]

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

    func isValid(for reference: ReferenceData?, patch expectedPatch: String?) -> Bool {
        guard matches(reference), expectedPatch == nil || expectedPatch == patch,
              patch.range(of: #"^\d{1,2}\.\d{1,2}$"#, options: .regularExpression) != nil,
              (1...60).contains(readings.count), Set(readings.map(\.id)).count == readings.count else { return false }
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

struct MetaRadarPreview: View {
    let snapshot: MetaRadarSnapshot
    let reference: ReferenceData?
    let query: String
    private var entries: [MetaObservation] {
        let filtered = snapshot.readings.filter { $0.matches(query) }
        var seen: Set<MetaObservation.Provider> = []
        let firstByProvider = filtered.filter { seen.insert($0.provider).inserted }
        let highlights = Set(firstByProvider.map(\.id))
        return firstByProvider + filtered.filter { !highlights.contains($0.id) }
    }

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                NavigationLink {
                    ScrollView {
                        MetaObservationShelf(snapshot: snapshot, reference: reference, query: query).padding()
                    }.background(hexaNavy).navigationTitle("Radar des compos").navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack {
                        Label("Radar des compos", systemImage: "chart.line.uptrend.xyaxis").font(.title3.bold())
                        Spacer()
                        Text(entries.count.formatted()).font(.caption)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("meta-radar")
                Text(snapshot.label).font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top) {
                        ForEach(entries) { entry in
                            Link(destination: entry.source) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.provider.rawValue).font(.caption2.bold()).foregroundStyle(entry.provider.color)
                                    Text(entry.title).font(.subheadline.bold()).lineLimit(2, reservesSpace: true)
                                    Text(entry.top4.formatted(.percent.precision(.fractionLength(1))) + " Top 4")
                                        .font(.caption.bold()).foregroundStyle(.mint)
                                }
                                .frame(width: 145, alignment: .leading).padding(12)
                                .background(entry.provider.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

struct MetaObservationShelf: View {
    let snapshot: MetaRadarSnapshot
    let reference: ReferenceData?
    let query: String
    @State private var provider: MetaObservation.Provider?

    private var entries: [MetaObservation] {
        snapshot.readings.filter {
            (provider == nil || $0.provider == provider) && $0.matches(query)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Radar des compos", systemImage: "chart.line.uptrend.xyaxis").font(.title2.bold())
                Spacer()
                Picker("Source", selection: $provider) {
                    Text("Toutes").tag(nil as MetaObservation.Provider?)
                    ForEach(MetaObservation.Provider.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }.labelsHidden().accessibilityIdentifier("meta-observation-source")
            }
            Text(snapshot.label)
                .font(.caption).foregroundStyle(.secondary)
            if !snapshot.matches(reference) {
                Text("Instantané antérieur au patch sélectionné.").font(.caption).foregroundStyle(.orange)
            }
            ForEach(entries) { entry in
                Link(destination: entry.source) { card(entry) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("observation-" + entry.id)
            }
            Text("Les rangs, périodes et regroupements de plateaux varient selon le fournisseur. MetaStats.gg signale des valeurs agrégées entre patches dans son atlas.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func card(_ entry: MetaObservation) -> some View {
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
            if snapshot.matches(reference), let reference {
                HStack(spacing: 6) {
                    ForEach(entry.champions, id: \.self) { key in
                        if let champion = reference.entries.first(where: { $0.id == "champion:" + key }) {
                            EntryIcon(entry: champion, size: 32)
                        }
                    }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack { metrics(entry) }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) { metrics(entry) }
            }
        }
    }
    @ViewBuilder private func metrics(_ entry: MetaObservation) -> some View {
        DashboardMetric(title: "Moyenne", value: entry.average.formatted(.number.precision(.fractionLength(2))))
        DashboardMetric(title: "Top 4", value: entry.top4.formatted(.percent.precision(.fractionLength(1))), accent: .mint)
        if let top1 = entry.top1 { DashboardMetric(title: "Top 1", value: top1.formatted(.percent.precision(.fractionLength(1)))) }
        if let games = entry.games { DashboardMetric(title: "Plateaux", value: games.formatted()) }
    }
}
