import Foundation
import SwiftUI
import Charts

struct TrackedMatch: Codable, Identifiable {
    struct Unit: Codable { let key: String; let stars: Int?; let items: [String] }
    struct Trait: Codable { let key: String; let count: Int; let tier: Int }
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
        let wins: Int
        let losses: Int
    }
    let id: String
    let riotID: String
    let region: String
    let observedAt: Double
    var matches: [TrackedMatch]
    let ranks: [Rank]
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

final class TrackerTransport: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor final class TrackerStore: ObservableObject {
    @Published private(set) var state = TrackerState()
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    private let file: URL
    private let transport = TrackerTransport()
    private var lastAttempt: Date?
    private var revision = 0
    private lazy var session = URLSession(configuration: .ephemeral, delegate: transport, delegateQueue: nil)
    private let service: URL?
    init(service: URL? = TrackerStore.bundledService) {
        self.service = service
        file = URL.applicationSupportDirectory.appendingPathComponent("HexaTFT/riot-tracker.json")
        if let data = try? Data(contentsOf: file), let cached = try? JSONDecoder().decode(TrackerState.self, from: data) {
            state = cached
        }
    }
    var profile: RiotProfile? { state.profiles.first { $0.id + ":" + $0.region == state.selected } }
    var points: [RankPoint] { state.selected.flatMap { state.points[$0] } ?? [] }

    nonisolated static var bundledService: URL? {
        guard let address = Bundle.main.object(forInfoDictionaryKey: "HexaTrackerService") as? String,
              let components = URLComponents(string: address), components.scheme == "https",
              components.host != nil, components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else { return nil }
        return components.url
    }
    var identity: RiotIdentity? { RiotIdentity(state.riotID, region: state.region) }
    var serviceAvailable: Bool { service != nil }

    private func persist(_ next: TrackerState) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        state = next
    }
    func saveProfile(_ identity: RiotIdentity) throws {
        var next = state
        next.region = identity.region
        next.riotID = identity.riotID
        next.selected = next.profiles.first {
            $0.region == identity.region && $0.riotID.caseInsensitiveCompare(identity.riotID) == .orderedSame
        }.map { $0.id + ":" + $0.region }
        try persist(next)
        revision += 1
        busy = false
        lastAttempt = nil
        message = nil
    }
    func autoRefresh() async {
        guard lastAttempt.map({ Date().timeIntervalSince($0) >= 180 }) ?? true else { return }
        await refresh()
    }
    func refresh() async {
        guard !busy, let service, let identity else { return }
        busy = true; lastAttempt = Date(); message = nil
        let ticket = revision
        defer { if ticket == revision { busy = false } }
        do {
            var request = URLRequest(url: service.appendingPathComponent("v1/tracker"), timeoutInterval: 60)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["name": identity.name, "tag": identity.tag, "region": identity.region])
            let (data, response) = try await session.data(for: request)
            guard ticket == revision else { return }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                let error = (try? JSONDecoder().decode([String:String].self, from: data))?["error"]
                throw DataIssue.invalid(error ?? "Le serveur Hexa ne répond pas.")
            }
            var incoming = try JSONDecoder().decode(RiotProfile.self, from: data)
            guard incoming.region == identity.region, incoming.matches.allSatisfy({ (1...8).contains($0.placement) }) else {
                throw DataIssue.invalid("Les données Riot reçues sont incohérentes.")
            }
            let key = incoming.id + ":" + incoming.region
            var next = state
            let previous = next.profiles.first { $0.id + ":" + $0.region == key }
            let merged = Dictionary((incoming.matches + (previous?.matches ?? [])).map { ($0.id, $0) }, uniquingKeysWith: { fresh, _ in fresh })
            incoming.matches = merged.values.sorted { $0.timestamp > $1.timestamp }
            next.profiles.removeAll { $0.id + ":" + $0.region == key }
            next.profiles.append(incoming); next.selected = key
            let date = Date(timeIntervalSince1970: incoming.observedAt)
            for rank in incoming.ranks {
                let last = next.points[key]?.last { $0.rank.queue == rank.queue }
                if last.map({ $0.date < date && ($0.rank.lp != rank.lp || $0.rank.division != rank.division || $0.rank.tier != rank.tier || date.timeIntervalSince($0.date) >= 86400) }) ?? true {
                    next.points[key, default: []].append(RankPoint(date: date, rank: rank))
                }
            }
            try persist(next)
        } catch {
            if ticket == revision, !Task.isCancelled { message = error.localizedDescription }
        }
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
    @State private var window = 20
    @State private var mode = "Tous"
    @State private var matchPatch = "Tous"
    @State private var rankPeriod = 30
    private var recent: [TrackedMatch] {
        Array((tracker.profile?.matches ?? []).filter { (mode == "Tous" || $0.modeName == mode) && (matchPatch == "Tous" || $0.patch == matchPatch) }.prefix(window))
    }
    var body: some View {
        List {
            if let identity = tracker.identity {
                Section {
                    Label(identity.riotID, systemImage: "person.crop.circle.fill").font(.title3.bold())
                    Button("Modifier le profil") { settings = true }
                    if let url = identity.publicProfile {
                        Link(destination: url) {
                            Label("Consulter le profil sur Tactics.Tools", systemImage: "arrow.up.right.square")
                        }.accessibilityIdentifier("tracker-public-profile")
                    }
                    if !tracker.serviceAvailable {
                        Text("Profil enregistré sur cet iPhone. Les statistiques et l’historique s’ouvrent sur Tactics.Tools. La synchronisation native attend la mise en service de la connexion Riot d’Hexa.").font(.footnote).foregroundStyle(.secondary)
                    } else if tracker.profile == nil, !tracker.busy {
                        Text("En attente du premier relevé Riot.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    Label("Mon compte TFT", systemImage: "person.crop.circle").font(.title3.bold())
                    Text("Ajoute ton Riot ID et choisis ta région. Ton profil restera accessible depuis cet onglet.").font(.subheadline).foregroundStyle(.secondary)
                    Button("Ajouter mon compte") { settings = true }
                }
            }
            if let profile = tracker.profile {
                Section(profile.riotID) {
                    LabeledContent("Région", value: profile.region.uppercased())
                    LabeledContent("Synchronisé", value: Date(timeIntervalSince1970: profile.observedAt).formatted())
                    if profile.ranks.isEmpty { Text("Aucun classement renvoyé par Riot.") }
                    ForEach(profile.ranks) { rank in
                        LabeledContent(rank.queue == "RANKED_TFT" ? "Classé" : rank.queue,
                            value: "\(rank.tier) \(rank.division) · \(rank.lp) LP")
                    }
                }
                recentSection(profile)
                if !tracker.points.isEmpty { historySection }
                if !recent.isEmpty { NavigationLink("Ma méta personnelle") { PersonalMetaView(matches: recent) } }
                Section("Parties terminées") {
                    ForEach(recent) { match in
                        NavigationLink { TrackedMatchView(match: match) } label: {
                            HStack {
                                Badge(text: "TOP \(match.placement)", color: match.placement <= 4 ? .mint : .orange)
                                VStack(alignment: .leading) { Text(match.modeName); Text(match.date, style: .date).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                Section {
                    ShareLink(item: csv, subject: Text("HexaTFT · historique")) { Label("Exporter les matchs", systemImage: "square.and.arrow.up") }
                }
            }
            if tracker.identity != nil {
                Section {
                    Button("Effacer le profil et l’historique local", role: .destructive) { confirming = true }
                }
            }
            if tracker.busy { ProgressView("Synchronisation Riot") }
            if let message = tracker.message { Text(message).font(.caption).foregroundStyle(.orange) }
            NavigationLink("Journal manuel") { JournalView() }
        }.navigationTitle("Tracker")
        .sheet(isPresented: $settings) { TrackerSettingsView() }
        .task(id: tracker.identity.map { $0.region + "/" + $0.riotID }) { await tracker.autoRefresh() }
        .refreshable { await tracker.refresh() }
        .confirmationDialog("Effacer l’historique Riot local ?", isPresented: $confirming) {
            Button("Effacer", role: .destructive) { tracker.erase() }
        }
    }
    private func recentSection(_ profile: RiotProfile) -> some View {
        Section("Performances récentes") {
            Picker("Mode", selection: $mode) {
                ForEach(["Tous"] + Set(profile.matches.map(\.modeName)).sorted(), id: \.self) { Text($0).tag($0) }
            }
            Picker("Version Riot", selection: $matchPatch) {
                ForEach(["Tous"] + Set(profile.matches.compactMap(\.patch)).sorted(), id: \.self) { Text($0).tag($0) }
            }
            Picker("Fenêtre", selection: $window) { ForEach([10,20,50,100], id: \.self) { Text("\($0) parties").tag($0) } }
            let summary = MatchSummary(recent)
            Text("\(summary.count) parties disponibles dans cette sélection").font(.caption)
            if let average = summary.average, let top4 = summary.top4, let wins = summary.wins {
                LabeledContent("Moyenne", value: average.formatted(.number.precision(.fractionLength(2))))
                LabeledContent("Top 4", value: top4.formatted(.percent.precision(.fractionLength(1))))
                LabeledContent("Victoires", value: wins.formatted(.percent.precision(.fractionLength(1))))
                Chart(Array(1...8), id: \.self) { place in
                    BarMark(x: .value("Place", String(place)), y: .value("Parties", recent.filter { $0.placement == place }.count))
                        .foregroundStyle(place <= 4 ? hexaGold : .gray)
                }.frame(height: 130).accessibilityLabel("Distribution des placements")
            }
        }
    }
    private var historySection: some View {
        let points = tracker.points.filter { $0.rank.queue == "RANKED_TFT" && $0.date >= Date().addingTimeInterval(-Double(rankPeriod)*86400) }
        return Section("LP enregistrés") {
            Picker("Période", selection: $rankPeriod) { Text("Jour").tag(1); Text("Semaine").tag(7); Text("Mois").tag(30) }.pickerStyle(.segmented)
            if points.isEmpty { Text("Aucun relevé classé sur cette période.") }
            else {
                Chart(points) { point in
                    PointMark(x: .value("Date", point.date), y: .value("LP", point.rank.lp)).foregroundStyle(hexaGold)
                }.frame(height: 160).accessibilityLabel("Relevés de LP")
                ForEach(points.suffix(5).reversed()) { point in
                    LabeledContent(point.date.formatted(date: .abbreviated, time: .shortened), value: "\(point.rank.tier) \(point.rank.division) · \(point.rank.lp) LP")
                }
            }
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
                    Picker("Région", selection: $region) {
                        ForEach(RiotIdentity.regions, id: \.0) { entry in Text(entry.1).tag(entry.0) }
                    }
                } footer: {
                    Text("Dans le client Riot, ton Riot ID est le nom suivi de # et de ton tag.")
                }
                if let error { Text(error).foregroundStyle(.orange) }
                Button("Enregistrer le profil") {
                    guard let identity else { return }
                    do {
                        try tracker.saveProfile(identity)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }.disabled(identity == nil)
            }.navigationTitle("Compte Riot")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
            .onAppear { riotID = tracker.state.riotID; region = tracker.state.region }
        }
    }
}

struct TrackedMatchView: View {
    @EnvironmentObject private var meta: MetaStore
    let match: TrackedMatch
    private var reference: ReferenceData? {
        let build = match.patch?.split(separator: " ").first(where: { $0.first?.isNumber == true }).map(String.init) ?? ""
        let version = build.split(separator: ".").prefix(2).joined(separator: ".")
        guard !version.isEmpty else { return nil }
        return ([meta.live].compactMap { $0 } + meta.archives).first {
            $0.pack.set == match.set.map(String.init) && $0.pack.data.first?.display_patch == version
        }?.reference
    }
    private func name(_ key: String, kind: String) -> String {
        reference?.entries.first { $0.id == kind + ":" + key }?.name ?? key
    }
    var body: some View {
        List {
            Section {
                LabeledContent("Placement", value: String(match.placement))
                LabeledContent("Mode", value: match.modeName)
                LabeledContent("Date", value: match.date.formatted())
                if let set = match.set { LabeledContent("Set", value: String(set)) }
                if let patch = match.patch { LabeledContent("Version Riot", value: patch) }
                if let level = match.level { LabeledContent("Niveau final", value: String(level)) }
            }
            Section("Équipe finale") {
                Text("Riot fournit les unités et leur équipement. Les coordonnées des cases ne figurent pas dans la réponse utilisée.").font(.caption)
                ForEach(Array(match.units.enumerated()), id: \.offset) { _, unit in
                    HStack {
                        if let entry = reference?.entries.first(where: { $0.id == "champion:" + unit.key }) { EntryIcon(entry: entry) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name(unit.key, kind: "champion")).font(.headline)
                            if let stars = unit.stars { Text("\(stars) ★").foregroundStyle(hexaGold) }
                            Text(unit.items.map { name($0, kind: "item") }.joined(separator: " · ")).font(.caption)
                        }
                    }
                }
            }
            Section("Traits et optimisations") {
                ForEach(match.traits, id: \.key) { trait in LabeledContent(name(trait.key, kind: "trait"), value: "\(trait.count)") }
                ForEach(Array(match.augments.enumerated()), id: \.offset) { _, key in Text(name(key, kind: "augment")) }
            }
            Section("Lobby · \(match.id)") {
                ForEach(Array(match.lobby.sorted { $0.placement < $1.placement }.enumerated()), id: \.offset) { _, player in
                    LabeledContent(player.name, value: String(player.placement))
                }
            }
        }.navigationTitle("Partie terminée")
    }
}


struct PersonalMetaView: View {
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
                        let names = latest.units.sorted { $0.items.count > $1.items.count }.prefix(3).map(\.key)
                        Text(names.joined(separator: " · ")).font(.caption)
                        NavigationLink("Voir le dernier plateau joué") { TrackedMatchView(match: latest) }
                    }
                }
            }
        }.navigationTitle("Ma méta personnelle")
    }
}
