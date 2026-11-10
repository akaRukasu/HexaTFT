import Foundation
import Security
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
    var endpoint: String = ""
    var region: String = "euw1"
    var riotID: String = ""
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
    init() {
        file = URL.applicationSupportDirectory.appendingPathComponent("HexaTFT/riot-tracker.json")
        if let data = try? Data(contentsOf: file), let cached = try? JSONDecoder().decode(TrackerState.self, from: data) {
            state = cached
        }
    }
    var profile: RiotProfile? { state.profiles.first { $0.id + ":" + $0.region == state.selected } }
    var points: [RankPoint] { state.selected.flatMap { state.points[$0] } ?? [] }

    private var keyQuery: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "HexaTFT.Tracker", kSecAttrAccount as String: "gateway"] }
    private func accessToken() -> String? {
        var result: CFTypeRef?
        var query = keyQuery
        query[kSecReturnData as String] = true
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func persist(_ next: TrackerState) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        state = next
    }
    func configure(endpoint: String, token: String, region: String, riotID: String) async {
        do {
            guard let url = URLComponents(string: endpoint), url.scheme == "https", url.host != nil,
                  url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
                throw DataIssue.invalid("L’adresse du serveur doit utiliser HTTPS.")
            }
            let reuse = endpoint == state.endpoint && accessToken() != nil
            guard token.count >= 24 || (token.isEmpty && reuse) else { throw DataIssue.invalid("Renseigne le jeton de ton serveur Hexa.") }
            if !token.isEmpty {
                let data = Data(token.utf8)
                let attrs = [kSecValueData as String: data]
                let status = SecItemUpdate(keyQuery as CFDictionary, attrs as CFDictionary)
                if status == errSecItemNotFound {
                    var entry = keyQuery
                    entry[kSecValueData as String] = data
                    entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                    guard SecItemAdd(entry as CFDictionary, nil) == errSecSuccess else { throw DataIssue.invalid("Impossible de sauvegarder le jeton.") }
                } else if status != errSecSuccess { throw DataIssue.invalid("Impossible de sauvegarder le jeton.") }
            }
            var next = state
            next.endpoint = endpoint; next.region = region; next.riotID = riotID
            try persist(next)
            revision += 1
            await refresh()
        } catch { message = error.localizedDescription }
    }
    func autoRefresh() async {
        guard !state.endpoint.isEmpty, !state.riotID.isEmpty,
              lastAttempt.map({ Date().timeIntervalSince($0) >= 180 }) ?? true else { return }
        await refresh()
    }
    func refresh() async {
        guard !busy else { return }
        busy = true; lastAttempt = Date(); message = nil
        let ticket = revision
        defer { busy = false }
        do {
            let id = state.riotID.split(separator: "#", omittingEmptySubsequences: false)
            guard id.count == 2, !id[0].isEmpty, !id[1].isEmpty,
                  let endpoint = URL(string: state.endpoint), endpoint.scheme == "https", let token = accessToken() else {
                throw DataIssue.invalid("Configure le serveur Hexa et le Riot ID au format Pseudo#TAG.")
            }
            var request = URLRequest(url: endpoint.appendingPathComponent("v1/tracker"), timeoutInterval: 60)
            request.httpMethod = "POST"
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["name": String(id[0]), "tag": String(id[1]), "region": state.region])
            let (data, response) = try await session.data(for: request)
            guard ticket == revision else { return }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                let error = (try? JSONDecoder().decode([String:String].self, from: data))?["error"]
                throw DataIssue.invalid(error ?? "Le serveur Hexa ne répond pas.")
            }
            var incoming = try JSONDecoder().decode(RiotProfile.self, from: data)
            guard incoming.region == state.region, incoming.matches.allSatisfy({ (1...8).contains($0.placement) }) else {
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
        revision += 1
        do {
            try persist(TrackerState())
            SecItemDelete(keyQuery as CFDictionary)
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
    @State private var rankPeriod = 30
    private var recent: [TrackedMatch] {
        Array((tracker.profile?.matches ?? []).filter { mode == "Tous" || $0.modeName == mode }.prefix(window))
    }
    var body: some View {
        List {
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
                    Button("Effacer les données Riot de cet iPhone", role: .destructive) { confirming = true }
                }
            } else {
                ContentUnavailableView("Mon compte TFT", systemImage: "person.crop.circle", description: Text("Associe ton Riot ID à un serveur Hexa autorisé pour récupérer tes matchs terminés."))
                Button("Configurer le tracker") { settings = true }
            }
            if tracker.busy { ProgressView("Synchronisation Riot") }
            if let message = tracker.message { Text(message).font(.caption).foregroundStyle(.orange) }
            NavigationLink("Journal manuel") { JournalView() }
        }.navigationTitle("Tracker")
        .toolbar { Button { settings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Réglages du tracker") }
        .sheet(isPresented: $settings) { TrackerSettingsView() }
        .refreshable { await tracker.autoRefresh() }
        .confirmationDialog("Effacer l’historique Riot local ?", isPresented: $confirming) {
            Button("Effacer", role: .destructive) { tracker.erase() }
        }
    }
    private func recentSection(_ profile: RiotProfile) -> some View {
        Section("Performances récentes") {
            Picker("Mode", selection: $mode) {
                ForEach(["Tous"] + Set(profile.matches.map(\.modeName)).sorted(), id: \.self) { Text($0).tag($0) }
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
    @State private var endpoint = ""
    @State private var token = ""
    @State private var riotID = ""
    @State private var region = "euw1"
    var body: some View {
        NavigationStack {
            Form {
                Section("Profil") {
                    TextField("Pseudo#TAG", text: $riotID).autocorrectionDisabled()
                    Picker("Région", selection: $region) {
                        ForEach(["euw1","eun1","na1","kr","jp1","br1","la1","la2","tr1","ru","oc1","sg2","tw2","vn2","me1"], id: \.self) {
                            Text($0.uppercased()).tag($0)
                        }
                    }
                }
                Section("Serveur Hexa") {
                    TextField("Adresse HTTPS", text: $endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Jeton d’accès du serveur", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Le serveur conserve la clé Riot. Le jeton ci-dessus sert uniquement à protéger l’accès à ton serveur.").font(.caption)
                }
                if let message = tracker.message { Text(message).foregroundStyle(.orange) }
                Button("Enregistrer et synchroniser") {
                    Task {
                        await tracker.configure(endpoint: endpoint, token: token, region: region, riotID: riotID.trimmingCharacters(in: .whitespacesAndNewlines))
                        if tracker.message == nil { dismiss() }
                    }
                }.disabled(tracker.busy)
            }.navigationTitle("Compte Riot")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
            .onAppear { endpoint = tracker.state.endpoint; riotID = tracker.state.riotID; region = tracker.state.region }
        }
    }
}

struct TrackedMatchView: View {
    @EnvironmentObject private var meta: MetaStore
    let match: TrackedMatch
    private var reference: ReferenceData? {
        let build = match.patch?.split(separator: " ").dropFirst().first.map(String.init) ?? match.patch ?? ""
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
