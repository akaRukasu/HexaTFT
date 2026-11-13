import Foundation
import SwiftUI
import Charts

struct TrackedMatch: Codable, Identifiable {
    struct Unit: Codable { let key: String; let stars: Int?; let items: [String]; var name: String? = nil }
    struct Trait: Codable { let key: String; let count: Int; let tier: Int; var name: String? = nil }
    struct LobbyPlayer: Codable { let placement: Int; let name: String }
    let id: String
    let timestamp: Double
    let patch: String?
    let set: Int?
    let queue: Int?
    let mode: String?
    let placement: Int
    let level: Int?
    let units: [Unit]
    let traits: [Trait]
    let augments: [String]
    let lobby: [LobbyPlayer]
    var duration: Double? = nil
    var lastRound: Int? = nil
    var goldLeft: Int? = nil
    var playerDamage: Int? = nil
    var playersEliminated: Int? = nil
    var source: String? = nil
    var date: Date { Date(timeIntervalSince1970: timestamp) }
    var modeName: String {
        switch queue { case 1100: return "Classé"; case 1090: return "Normal"; case 1160: return "Double Up"; case 1130: return "Hyper Roll"; default: return mode ?? "Autre" }
    }
}
struct RiotProfile: Codable {
    struct Rank: Codable, Identifiable {
        var id: String { queue }
        let queue: String
        let tier: String
        let division: String
        let lp: Int
        let wins: Int?
        let losses: Int?
        var games: Int? = nil
        var top4Count: Int? = nil
        var rankPosition: Int? = nil
        var name: String {
            switch queue {
            case "RANKED_TFT": "Classé"
            case "RANKED_TFT_DOUBLE_UP": "Double Up"
            case "RANKED_TFT_TURBO": "Hyper Roll"
            default: queue
            }
        }
        var displayTier: String {
            let names = ["IRON": "Fer", "BRONZE": "Bronze", "SILVER": "Argent", "GOLD": "Or",
                         "PLATINUM": "Platine", "EMERALD": "Émeraude", "DIAMOND": "Diamant",
                         "MASTER": "Maître", "GRANDMASTER": "Grand maître", "CHALLENGER": "Challenger"]
            let title = names[tier] ?? tier.capitalized
            return ["MASTER", "GRANDMASTER", "CHALLENGER"].contains(tier) ? title :
                [title, division].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }
    let id: String
    let riotID: String
    let region: String
    let observedAt: Double
    var matches: [TrackedMatch]
    let ranks: [Rank]
    var source: String? = nil
    var checkedAt: Date? = nil
    var publishedPoints: [RankPoint]? = nil
    var sourceName: String { source ?? "Riot Games · historique local" }
}
struct RankPoint: Codable, Identifiable {
    let date: Date
    let rank: RiotProfile.Rank
    var id: String { "\(rank.queue)-\(date.timeIntervalSince1970)" }
}
struct TrackerState: Codable {
    var profiles: [RiotProfile] = []
    var points: [String: [RankPoint]] = [:]
    var selected: String?
    var region: String = "euw1"
    var riotID: String = ""
}
struct RiotIdentity {
    static let regions = [
        ("euw1", "Europe Ouest", "euw"), ("eun1", "Europe Nord et Est", "eune"),
        ("na1", "Amérique du Nord", "na"), ("kr", "Corée", "kr"), ("jp1", "Japon", "jp"),
        ("br1", "Brésil", "br"), ("la1", "Amérique latine Nord", "lan"), ("la2", "Amérique latine Sud", "las"),
        ("tr1", "Turquie", "tr"), ("ru", "Russie", "ru"), ("oc1", "Océanie", "oce"),
        ("sg2", "Asie du Sud-Est", "sea"), ("tw2", "Taïwan", "tw"), ("vn2", "Vietnam", "vn"),
        ("me1", "Moyen-Orient", "me")
    ]
    let name: String
    let tag: String
    let region: String
    var riotID: String { name + "#" + tag }
    var regionName: String { Self.regions.first(where: { $0.0 == region })?.1 ?? region.uppercased() }

    init?(_ input: String, region: String) {
        let parts = input.split(separator: "#", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2, (1...32).contains(parts[0].count), (1...12).contains(parts[1].count),
              !parts.contains(where: { $0 == "." || $0 == ".." || $0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) }),
              Self.regions.contains(where: { $0.0 == region }) else { return nil }
        name = parts[0]
        tag = parts[1]
        self.region = region
    }

    var publicProfile: URL? {
        guard let platform = Self.regions.first(where: { $0.0 == region })?.2 else { return nil }
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%#?;"))
        guard let name = name.addingPercentEncoding(withAllowedCharacters: allowed),
              let tag = tag.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://tactics.tools/player/" + platform + "/" + name + "/" + tag)
    }

    var opggProfile: URL? {
        guard let platform = Self.regions.first(where: { $0.0 == region })?.2 else { return nil }
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%#?;"))
        guard let slug = (name + "-" + tag).addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://op.gg/tft/summoners/" + platform + "/" + slug)
    }
}
struct MatchSummary {
    let count: Int
    let average: Double?
    let top4: Double?
    let wins: Double?
    init(_ matches: [TrackedMatch]) {
        let valid = matches.filter { (1...8).contains($0.placement) }
        count = valid.count
        average = valid.isEmpty ? nil : Double(valid.map(\.placement).reduce(0, +)) / Double(valid.count)
        top4 = valid.isEmpty ? nil : Double(valid.filter { $0.placement <= 4 }.count) / Double(valid.count)
        wins = valid.isEmpty ? nil : Double(valid.filter { $0.placement == 1 }.count) / Double(valid.count)
    }
}

@MainActor final class TrackerStore: ObservableObject {
    @Published private(set) var state = TrackerState()
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    private let file: URL
    private var lastAttempt: Date?
    private var revision = 0
    init(directory: URL? = nil) {
        file = (directory ?? URL.applicationSupportDirectory.appendingPathComponent("HexaTFT")).appendingPathComponent("riot-tracker.json")
        #if DEBUG
        if let fixture = ProcessInfo.processInfo.environment["HEXA_TRACKER_UI_FIXTURE"],
           let cached = try? JSONDecoder().decode(TrackerState.self, from: Data(fixture.utf8)) {
            state = cached
            lastAttempt = .now
            return
        }
        #endif
        if let data = try? Data(contentsOf: file), let cached = try? JSONDecoder().decode(TrackerState.self, from: data) {
            state = cached
        }
    }
    var profile: RiotProfile? { state.profiles.first { $0.id + ":" + $0.region == state.selected } }
    var points: [RankPoint] { state.selected.flatMap { state.points[$0] } ?? [] }

    var identity: RiotIdentity? { RiotIdentity(state.riotID, region: state.region) }

    private func persist(_ next: TrackerState) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        state = next
    }
    func saveProfile(_ identity: RiotIdentity) throws {
        var next = state
        next.region = identity.region
        next.riotID = identity.riotID
        let matching = next.profiles.filter {
            $0.region == identity.region && $0.riotID.caseInsensitiveCompare(identity.riotID) == .orderedSame
        }
        next.selected = (matching.first { $0.source == "OP.GG" } ?? matching.first).map { $0.id + ":" + $0.region }
        try persist(next)
        revision += 1
        busy = false
        lastAttempt = nil
        message = nil
    }
    func autoRefresh() async {
        guard lastAttempt.map({ Date().timeIntervalSince($0) >= 900 }) ??
            (profile?.checkedAt.map { Date().timeIntervalSince($0) >= 900 } ?? true) else { return }
        await refresh()
    }
    func refresh() async {
        guard !busy, let identity, lastAttempt.map({ Date().timeIntervalSince($0) >= 60 }) ?? true else { return }
        busy = true; lastAttempt = Date(); message = nil
        let ticket = revision
        defer { if ticket == revision { busy = false } }
        do {
            let incoming = try await OPGGTracker.fetch(identity)
            guard ticket == revision, !Task.isCancelled else { return }
            try ingest(incoming, for: identity)
        } catch {
            if ticket == revision, !Task.isCancelled {
                message = (error as? DataIssue)?.localizedDescription ??
                    "OP.GG est momentanément indisponible. La dernière synchronisation reste consultable."
            }
        }
    }
    func ingest(_ profile: RiotProfile, for identity: RiotIdentity) throws {
        guard let saved = self.identity, saved.region == identity.region,
              saved.riotID == identity.riotID, profile.region == identity.region,
              profile.riotID.caseInsensitiveCompare(identity.riotID) == .orderedSame,
              !profile.id.isEmpty, profile.observedAt.isFinite, profile.observedAt > 0,
              profile.matches.allSatisfy({ (1...8).contains($0.placement) && $0.timestamp.isFinite }) else {
            throw DataIssue.invalid("Les données reçues ne correspondent pas au profil enregistré.")
        }
        var incoming = profile
        let key = incoming.id + ":" + incoming.region
        var next = state
        let previous = next.profiles.first { $0.id + ":" + $0.region == key }
        guard previous.map({ $0.observedAt <= incoming.observedAt }) != false else { return }
        let merged = Dictionary((incoming.matches + (previous?.matches ?? [])).map { ($0.id, $0) }, uniquingKeysWith: { fresh, _ in fresh })
        incoming.matches = merged.values.sorted { $0.timestamp > $1.timestamp }
        next.profiles.removeAll { $0.id + ":" + $0.region == key }
        next.profiles.append(incoming); next.selected = key
        let date = Date(timeIntervalSince1970: incoming.observedAt)
        if let published = incoming.publishedPoints {
            let combined = published + (next.points[key] ?? [])
            next.points[key] = Dictionary(combined.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
                .values.sorted { $0.date < $1.date }
        }
        for rank in incoming.ranks {
            let last = next.points[key]?.last { $0.rank.queue == rank.queue }
            if last.map({ $0.date < date && ($0.rank.lp != rank.lp || $0.rank.division != rank.division || $0.rank.tier != rank.tier || date.timeIntervalSince($0.date) >= 86400) }) ?? true {
                next.points[key, default: []].append(RankPoint(date: date, rank: rank))
            }
        }
        try persist(next)
    }

    func erase() {
        do {
            try persist(TrackerState())
            revision += 1
            busy = false
            lastAttempt = nil
            message = nil
        } catch { message = error.localizedDescription }
    }
}

struct TrackerView: View {
    @EnvironmentObject private var tracker: TrackerStore
    @State private var settings = false
    @State private var confirming = false
    @State private var selectedPage: ProfilePage = .hexa

    private enum ProfilePage: String, CaseIterable {
        case publicProfile = "Tactics.Tools"
        case hexa = "Vue d’ensemble"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let identity = tracker.identity, let url = identity.publicProfile {
                Picker("Profil TFT", selection: $selectedPage) {
                    ForEach([ProfilePage.hexa, .publicProfile], id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal).padding(.vertical, 8)
                .accessibilityIdentifier("tracker-profile-tabs")
                if selectedPage == .publicProfile {
                    VStack(spacing: 0) {
                        HStack {
                            Label(identity.riotID, systemImage: "person.crop.circle")
                                .font(.headline).lineLimit(1)
                                .accessibilityLabel(identity.riotID)
                                .accessibilityIdentifier("tracker-identity")
                            Spacer()
                            Label("Fiche publique", systemImage: "globe").font(.caption).foregroundStyle(.secondary)
                        }.padding(.horizontal).padding(.vertical, 8)
                        EmbeddedPage(url: url, allowedHosts: ["tactics.tools", "www.tactics.tools"])
                            .id(url)
                            .accessibilityIdentifier("tracker-public-profile")
                    }
                } else {
                    nativeDashboard
                }
            } else {
                nativeDashboard
            }
        }.background(hexaNavy).navigationTitle("Tracker").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $settings) { TrackerSettingsView() }
        .task(id: tracker.identity?.publicProfile) { await tracker.autoRefresh() }
        .confirmationDialog("Effacer l’historique Riot local ?", isPresented: $confirming) {
            Button("Effacer", role: .destructive) { tracker.erase(); selectedPage = .hexa }
        }
        .toolbar {
            if tracker.identity != nil {
                Menu {
                    Button("Modifier le profil", systemImage: "pencil") { settings = true }
                    Button(role: .destructive) { confirming = true } label: {
                        Label("Effacer le profil et l’historique local", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }.accessibilityLabel("Options du compte")
            }
        }
    }

    private var nativeDashboard: some View {
        List {
            Section {
                if let identity = tracker.identity {
                    TrackerProfileCard(identity: identity, profile: tracker.profile)
                        .accessibilityIdentifier("tracker-identity")
                } else {
                    FeatureBanner(eyebrow: "SUIVI TFT", title: "Mon compte TFT",
                                  detail: "Ton rang, tes parties et ta progression au même endroit.", icon: "chart.xyaxis.line", accent: .mint)
                }
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            if tracker.identity == nil {
                Section {
                    Button { settings = true } label: {
                        Label("Ajouter mon compte", systemImage: "person.badge.plus")
                            .font(.headline).frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(hexaNavy)
                    Text("Entre ton Riot ID avec son #TAG et sélectionne ton serveur.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if let profile = tracker.profile {
                TrackerDashboard(profile: profile, points: tracker.points)
                    .id(profile.id + ":" + profile.region)
            } else if tracker.identity != nil {
                Section {
                    Panel {
                        Label("Rang et parties", systemImage: "chart.bar.xaxis").font(.headline)
                        Text(tracker.busy ? "Hexa charge ton rang et ton historique public depuis OP.GG." :
                            "Hexa utilise les données publiques d’OP.GG. Tu peux également consulter ta fiche Tactics.Tools ici.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { selectedPage = .publicProfile } label: {
                            Label("Voir mon profil TFT", systemImage: "person.crop.rectangle")
                                .font(.headline).frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(hexaNavy)
                    }
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if tracker.busy { ProgressView("Synchronisation OP.GG") }
            if let message = tracker.message { Text(message).font(.caption).foregroundStyle(.orange) }
            Section {
                if let url = tracker.identity?.opggProfile {
                    Link(destination: url) { Label("Fiche source OP.GG", systemImage: "arrow.up.right.square") }
                }
                NavigationLink("Journal manuel") { JournalView() }
            }
        }.scrollContentBackground(.hidden).refreshable { await tracker.refresh() }
    }

}

private struct TrackerProfileCard: View {
    let identity: RiotIdentity
    let profile: RiotProfile?
    private var rank: RiotProfile.Rank? { profile?.ranks.first { $0.queue == "RANKED_TFT" } ?? profile?.ranks.first }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(identity.regionName, systemImage: "globe.europe.africa")
                .font(.caption.weight(.semibold)).foregroundStyle(.mint)
            Text(identity.riotID).font(.title.bold()).accessibilityAddTraits(.isHeader)
            if let rank {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { rankLabel(rank); Spacer(minLength: 0); lpLabel(rank) }
                    VStack(alignment: .leading, spacing: 8) { rankLabel(rank); lpLabel(rank) }
                }
            }
            if let profile {
                Label(profile.sourceName + " · rang relevé le " + Date(timeIntervalSince1970: profile.observedAt).formatted(date: .abbreviated, time: .shortened),
                      systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                if let lastMatch = profile.matches.first {
                    Text("Dernière partie reçue · " + lastMatch.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let checked = profile.checkedAt {
                    Text("Vérifié le " + checked.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Label("Compte enregistré", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(.linearGradient(colors: [.mint.opacity(0.20), hexaNavy], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.mint.opacity(0.22)))
    }
    private func rankLabel(_ rank: RiotProfile.Rank) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rank.name).font(.caption).foregroundStyle(.secondary)
            Label(rank.displayTier, systemImage: "medal.fill").font(.headline).foregroundStyle(hexaGold)
        }
    }
    private func lpLabel(_ rank: RiotProfile.Rank) -> some View {
        Text("\(rank.lp.formatted()) LP").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(.mint)
    }
}

struct TrackerDashboard: View {
    @EnvironmentObject private var meta: MetaStore
    let profile: RiotProfile
    let points: [RankPoint]
    @State private var tab: Tab = .summary
    @State private var window = 20
    @State private var mode: String?
    @State private var selectedSet: Int?
    @State private var selectedPatch: String?
    @State private var rankPeriod = 30
    @State private var rankQueue = "RANKED_TFT"

    enum Tab: String, CaseIterable {
        case summary = "Aperçu", matches = "Parties", progress = "Progression"
    }

    private var recent: [TrackedMatch] {
        Array(profile.matches.filter {
            (mode == nil || $0.modeName == mode) && (selectedSet == nil || $0.set == selectedSet) &&
            (selectedPatch == nil || $0.patch == selectedPatch)
        }.prefix(window))
    }

    var body: some View {
        Section {
            Picker("Tableau de bord", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("tracker-native-tabs")
        }
        switch tab {
        case .summary:
            filters
            performance
            if !recent.isEmpty {
                Section("Derniers résultats") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recent.prefix(10)) { match in
                                NavigationLink { TrackedMatchView(match: match) } label: {
                                    VStack(spacing: 6) {
                                        Text("#\(match.placement)").font(.headline.monospacedDigit())
                                            .foregroundStyle(match.placement == 1 ? hexaGold : match.placement <= 4 ? .mint : .orange)
                                        Text(match.date.formatted(.dateTime.day().month(.abbreviated)))
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }.frame(minWidth: 52).padding(.vertical, 10)
                                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                                    .accessibilityIdentifier("tracker-recent-" + match.id)
                                    .accessibilityLabel("Top \(match.placement), \(match.modeName), \(match.date.formatted(date: .abbreviated, time: .shortened))")
                            }
                        }
                    }
                    Button("Voir toutes les parties de cette sélection") { tab = .matches }
                }
                NavigationLink("Ma méta personnelle") { PersonalMetaView(matches: recent) }
            }
            ranks
        case .matches:
            filters
            matches
        case .progress:
            rankHistory
            setHistory
        }
    }

    private var ranks: some View {
        Section("Classements · " + profile.sourceName) {
            if profile.ranks.isEmpty { Text("Aucun classement fourni pour ce compte.").foregroundStyle(.secondary) }
            ForEach(profile.ranks) { rank in
                Panel {
                    Label(rank.name, systemImage: "medal").font(.headline).foregroundStyle(.mint)
                    Text(rank.displayTier).font(.title2.bold())
                    ViewThatFits(in: .horizontal) {
                        HStack { rankMetrics(rank) }
                        VStack(alignment: .leading) { rankMetrics(rank) }
                    }
                    if let place = rank.rankPosition, place > 0 {
                        Label("Nº \(place.formatted()) sur le serveur", systemImage: "list.number")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder private func rankMetrics(_ rank: RiotProfile.Rank) -> some View {
        DashboardMetric(title: "LP", value: rank.lp.formatted())
        if let games = rank.games { DashboardMetric(title: "Parties", value: games.formatted()) }
        if let top4 = rank.top4Count { DashboardMetric(title: "Top 4", value: top4.formatted(), accent: .mint) }
        if let wins = rank.wins { DashboardMetric(title: "Victoires", value: wins.formatted(), accent: .mint) }
        if let losses = rank.losses { DashboardMetric(title: "Défaites", value: losses.formatted(), accent: .orange) }
    }

    private var filters: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sélection").font(.subheadline.bold())
                    Text(([mode ?? "Tous les modes", "\(window) parties max."] +
                          [selectedSet.map { "Set \($0)" }, selectedPatch].compactMap { $0 }).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Picker("Mode", selection: $mode) {
                        Text("Tous les modes").tag(nil as String?)
                        ForEach(Set(profile.matches.map(\.modeName)).sorted(), id: \.self) { Text($0).tag(Optional($0)) }
                    }
                    Picker("Set", selection: $selectedSet) {
                        Text("Tous les sets").tag(nil as Int?)
                        ForEach(Set(profile.matches.compactMap(\.set)).sorted(by: >), id: \.self) { Text("Set \($0)").tag(Optional($0)) }
                    }
                    Picker("Version du jeu", selection: $selectedPatch) {
                        Text("Toutes les versions").tag(nil as String?)
                        ForEach(Set(profile.matches.compactMap(\.patch)).sorted(), id: \.self) { Text($0).tag(Optional($0)) }
                    }
                    Picker("Fenêtre", selection: $window) {
                        ForEach([10, 20, 50, 100], id: \.self) { Text("\($0) parties").tag($0) }
                    }
                } label: {
                    Label("Filtres", systemImage: "line.3.horizontal.decrease.circle").font(.subheadline.bold())
                }
            }
        }
    }

    private var performance: some View {
        let summary = MatchSummary(recent)
        return Section {
            Panel {
                Label("Performances récentes", systemImage: "chart.bar.xaxis").font(.headline)
                Text("\(summary.count) parties dans la sélection").font(.caption).foregroundStyle(.secondary)
                if let average = summary.average, let top4 = summary.top4, let wins = summary.wins {
                    ViewThatFits(in: .horizontal) {
                        HStack { performanceMetrics(average, top4, wins) }
                        VStack(alignment: .leading) { performanceMetrics(average, top4, wins) }
                    }
                    Chart(1...8, id: \.self) { place in
                        BarMark(x: .value("Place", String(place)), y: .value("Parties", recent.filter { $0.placement == place }.count))
                            .foregroundStyle(place == 1 ? hexaGold.gradient : place <= 4 ? Color.mint.gradient : Color.orange.gradient)
                            .cornerRadius(4)
                    }.frame(height: 148).accessibilityLabel("Distribution des placements")
                } else {
                    Text("Aucune partie disponible pour cette sélection.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
    }

    @ViewBuilder private func performanceMetrics(_ average: Double, _ top4: Double, _ wins: Double) -> some View {
        DashboardMetric(title: "Moyenne", value: average.formatted(.number.precision(.fractionLength(2))))
        DashboardMetric(title: "Top 4", value: top4.formatted(.percent.precision(.fractionLength(1))), accent: .mint)
        DashboardMetric(title: "Top 1", value: wins.formatted(.percent.precision(.fractionLength(1))))
    }

    private var matches: some View {
        Section("Parties terminées") {
            if recent.isEmpty { Text("Aucune partie pour ces filtres.").foregroundStyle(.secondary) }
            ForEach(recent) { match in
                NavigationLink { TrackedMatchView(match: match) } label: {
                    HStack(spacing: 12) {
                        Badge(text: "#\(match.placement)", color: match.placement <= 4 ? .mint : .orange)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(match.modeName).font(.headline)
                            Text(match.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            if let reference = meta.matchReference(match) {
                                HStack(spacing: 4) {
                                    ForEach(Array(match.units.sorted { $0.items.count > $1.items.count }.prefix(4).enumerated()), id: \.offset) { _, unit in
                                        if let entry = reference.entries.first(where: { $0.id == "champion:" + unit.key }) {
                                            EntryIcon(entry: entry, size: 26)
                                        }
                                    }
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        if let set = match.set { Text("SET \(set)").font(.caption2.bold()).foregroundStyle(.secondary) }
                    }
                }
            }
            if !recent.isEmpty {
                ShareLink(item: csv, subject: Text("HexaTFT · historique")) {
                    Label("Exporter les parties", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var rankHistory: some View {
        let queues = Set(points.map(\.rank.queue)).sorted()
        let activeQueue = queues.contains(rankQueue) ? rankQueue : queues.first
        let selected = points.filter { $0.rank.queue == activeQueue && $0.date >= Date().addingTimeInterval(-Double(rankPeriod) * 86400) }
        return Section("Évolution des LP") {
            if queues.count > 1 {
                Picker("File", selection: Binding(get: { activeQueue ?? rankQueue }, set: { rankQueue = $0 })) {
                    ForEach(queues, id: \.self) { queue in Text(points.first { $0.rank.queue == queue }?.rank.name ?? queue).tag(queue) }
                }
            }
            Picker("Période", selection: $rankPeriod) {
                Text("Jour").tag(1); Text("Semaine").tag(7); Text("Mois").tag(30)
            }.pickerStyle(.segmented)
            if selected.isEmpty {
                Text("Aucun relevé sur cette période.").foregroundStyle(.secondary)
            } else {
                Chart(selected) { point in
                    PointMark(x: .value("Date", point.date), y: .value("LP", point.rank.lp))
                        .foregroundStyle(hexaGold)
                }.frame(height: 160).accessibilityLabel("Relevés de LP")
                ForEach(selected.suffix(5).reversed()) { point in
                    LabeledContent(point.date.formatted(date: .abbreviated, time: .shortened),
                                   value: "\(point.rank.displayTier) · \(point.rank.lp) LP")
                }
            }
            Text("Les LP sont affichés dans le rang atteint à chaque relevé · " + profile.sourceName).font(.caption)
        }
    }

    private var setHistory: some View {
        let groups = Dictionary(grouping: profile.matches) { $0.set }
        return Section("Bilan par set") {
            ForEach(groups.keys.sorted { ($0 ?? 0) > ($1 ?? 0) }, id: \.self) { set in
                let summary = MatchSummary(groups[set] ?? [])
                VStack(alignment: .leading, spacing: 8) {
                    Text(set.map { "Set \($0)" } ?? "Set non renseigné").font(.headline)
                    HStack {
                        DashboardMetric(title: "Parties", value: summary.count.formatted())
                        if let average = summary.average {
                            DashboardMetric(title: "Moyenne", value: average.formatted(.number.precision(.fractionLength(2))))
                        }
                        if let top4 = summary.top4 {
                            DashboardMetric(title: "Top 4", value: top4.formatted(.percent.precision(.fractionLength(1))), accent: .mint)
                        }
                    }
                }
            }
            Text("Bilan calculé sur les parties synchronisées dans Hexa.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var csv: String {
        (["match,date,placement,file,set"] + recent.map { "\($0.id),\($0.date.ISO8601Format()),\($0.placement),\($0.queue ?? 0),\($0.set ?? 0)" }).joined(separator: "\n")
    }
}

struct TrackerSettingsView: View {
    @EnvironmentObject private var tracker: TrackerStore
    @Environment(\.dismiss) private var dismiss
    @State private var riotID = ""
    @State private var region = "euw1"
    @State private var error: String?
    private var identity: RiotIdentity? { RiotIdentity(riotID, region: region) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Pseudo#TAG", text: $riotID)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .submitLabel(.done).onSubmit(save)
                    Picker("Région", selection: $region) {
                        ForEach(RiotIdentity.regions, id: \.0) { entry in Text(entry.1).tag(entry.0) }
                    }
                } footer: {
                    Text("Dans le client Riot, ton Riot ID est le nom suivi de # et de ton tag.")
                }
                if let error { Text(error).foregroundStyle(.orange) }
            }.navigationTitle("Compte Riot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save).disabled(identity == nil)
                        .accessibilityIdentifier("tracker-save")
                }
            }
            .onAppear { riotID = tracker.state.riotID; region = tracker.state.region }
        }
    }
    private func save() {
        guard let identity else { return }
        do {
            try tracker.saveProfile(identity)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct TrackedMatchView: View {
    @EnvironmentObject private var meta: MetaStore
    let match: TrackedMatch
    private var reference: ReferenceData? { meta.matchReference(match) }
    private func name(_ key: String, kind: String, fallback: String? = nil) -> String {
        reference?.entries.first { $0.id == kind + ":" + key }?.name ?? fallback ?? key
    }
    var body: some View {
        List {
            Section {
                FeatureBanner(eyebrow: match.modeName.uppercased(), title: "Top " + String(match.placement),
                              detail: match.date.formatted(), icon: "flag.checkered", accent: match.placement <= 4 ? .mint : .orange)
                    .listRowBackground(Color.clear)
                if let set = match.set { LabeledContent("Set", value: String(set)) }
                if let patch = match.patch { LabeledContent("Version", value: patch) }
                if let source = match.source { LabeledContent("Source", value: source) }
                if let level = match.level { LabeledContent("Niveau final", value: String(level)) }
                if let duration = match.duration, duration.isFinite, (0...86_400).contains(duration) {
                    LabeledContent("Durée totale", value: Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                }
                if let round = match.lastRound { LabeledContent("Dernière manche", value: round.formatted()) }
                if let gold = match.goldLeft { LabeledContent("Or restant", value: gold.formatted()) }
                if let damage = match.playerDamage { LabeledContent("Dégâts aux tacticiens", value: damage.formatted()) }
                if let eliminated = match.playersEliminated { LabeledContent("Tacticiens éliminés", value: eliminated.formatted()) }
            }
            Section("Équipe finale") {
                Text("Champions et objets en fin de partie · positionnement indisponible").font(.caption).foregroundStyle(.secondary)
                ForEach(Array(match.units.enumerated()), id: \.offset) { _, unit in
                    HStack {
                        if let entry = reference?.entries.first(where: { $0.id == "champion:" + unit.key }) { EntryIcon(entry: entry) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name(unit.key, kind: "champion", fallback: unit.name)).font(.headline)
                            if let stars = unit.stars { Text("\(stars) ★").foregroundStyle(hexaGold) }
                            ForEach(Array(unit.items.enumerated()), id: \.offset) { _, key in
                                HStack {
                                    if let entry = reference?.entries.first(where: { $0.id == "item:" + key }) {
                                        EntryIcon(entry: entry, size: 22)
                                    }
                                    Text(name(key, kind: "item")).font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            if !match.traits.isEmpty || !match.augments.isEmpty {
                Section(match.augments.isEmpty ? "Traits actifs" : "Traits et optimisations") {
                    ForEach(match.traits, id: \.key) { trait in
                        LabeledContent(name(trait.key, kind: "trait", fallback: trait.name), value: "\(trait.count)")
                    }
                    ForEach(Array(match.augments.enumerated()), id: \.offset) { _, key in Text(name(key, kind: "augment")) }
                }
            }
            if !match.lobby.isEmpty {
                Section("Lobby") {
                    ForEach(Array(match.lobby.sorted { $0.placement < $1.placement }.enumerated()), id: \.offset) { _, player in
                        LabeledContent(player.name, value: String(player.placement))
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(hexaNavy).navigationTitle("Partie terminée")
    }
}


extension MetaStore {
    func matchReference(_ match: TrackedMatch) -> ReferenceData? {
        guard let set = match.set.map(String.init) else { return nil }
        let build = match.patch?.split(separator: " ").first { $0.first?.isNumber == true } ?? ""
        let version = build.split(separator: ".").prefix(2).joined(separator: ".")
        let snapshots = ([live].compactMap { $0 } + archives).filter { $0.pack.set == set }
        let exact = snapshots.first {
            !version.isEmpty && ($0.reference?.version.hasPrefix(version + ".") == true || $0.pack.data.first?.display_patch == version)
        }
        return exact?.reference ?? snapshots.first?.reference
    }
}

struct PersonalMetaView: View {
    @EnvironmentObject private var meta: MetaStore
    let matches: [TrackedMatch]
    private struct Row: Identifiable {
        let id: String
        let matches: [TrackedMatch]
    }
    private var groups: [Row] {
        Dictionary(grouping: matches.filter { !$0.units.isEmpty }) { match in
            let team = match.units.map(\.key).sorted().joined(separator: "|")
            return "\(match.set ?? 0):\(match.queue ?? 0):" + team
        }.map { Row(id: $0.key, matches: $0.value) }.sorted { ($0.matches.count, $0.id) > ($1.matches.count, $1.id) }
    }
    var body: some View {
        List {
            Section {
                Text("Groupes par équipe finale exacte, set et file. Les moyennes utilisent uniquement tes matchs de la sélection.").font(.caption)
            }
            ForEach(groups) { group in
                if let latest = group.matches.first {
                    let summary = MatchSummary(group.matches)
                    Section("\(summary.count) partie(s) · \(latest.modeName)") {
                        if let average = summary.average { LabeledContent("Moyenne", value: average.formatted(.number.precision(.fractionLength(2)))) }
                        if let rate = summary.top4 { LabeledContent("Top 4", value: rate.formatted(.percent)) }
                        if let rate = summary.wins { LabeledContent("Top 1", value: rate.formatted(.percent)) }
                        let names = latest.units.sorted { $0.items.count > $1.items.count }.prefix(3).map { unit in
                            meta.matchReference(latest)?.entries.first { $0.id == "champion:" + unit.key }?.name ?? unit.key
                        }
                        Text(names.joined(separator: " · ")).font(.caption)
                        NavigationLink("Voir le dernier plateau joué") { TrackedMatchView(match: latest) }
                    }
                }
            }
        }.navigationTitle("Ma méta personnelle")
    }
}
