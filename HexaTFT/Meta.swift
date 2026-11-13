import Foundation
import Combine

struct MetaUnit: Codable, Identifiable {
    let name: String
    let items: [String]?
    let star_level: Double?
    var id: String { name }
}
struct MetaPosition: Codable { let board_position: Int; let unit_api_name: String }
struct MetaStats: Codable {
    let avg_placement: Double
    let nb_games: Int
    let pick_rate: Double
    let top_1_percent: Double
    let top_4_percent: Double
    let tier: Int
}
struct MetaVariant: Codable {
    let units: [MetaUnit]
    let units_positions: [MetaPosition]?
    let nb_boards: Int?
    let avg_placement: Double?
}
struct MetaVariations: Codable {
    let early: [MetaVariant]?
    let flex_options: [MetaVariant]?
    let levels: [String: [MetaVariant]]?
    let stages: [String: [MetaVariant]]?
}
struct MetaStrategy: Codable {
    let type: String?
    let level_stage: [String: String]?
}
struct MetaHolder: Codable {
    struct Holder: Codable { let early_game_carry_api_name: String }
    let end_game_carry_api_name: String
    let stats: [Holder]
}
struct MetaUnitStats: Codable {
    struct Trio: Codable {
        let item_api_names: [String]
        let nb_boards: Int?
        let avg_placement: Double?
        let pick_rate: Double?
    }
    let name: String
    let item_trios: [Trio]?
}
struct MetaTrait: Codable { let trait_api_name: String }
struct MetaCondition: Codable {
    let name: String
    let type: String
    let avg_placement: Double?
    let avg_placement_without: Double?
    let unit_star_level: Int?
    let trait_min_count: Int?
}
struct AuthoredGuide: Codable {
    let title: String
    let stages: [String: String]
    let conditions: String
    let pivot: String
    let positioning: String
    let itemPlans: [String: String]
    var traitThresholds: [Int]? = nil
}
struct PublishedMetaPlan: Codable {
    let name: String
    let difficulty: Int?
    let targetLevel: Int?
    let requirements: [String]
    let primaryUnit: String?
    let frontline: String?
    let smallSample: Bool
}
struct MetaComp: Codable, Identifiable {
    let comp_id: String
    let slug: String
    let stats: MetaStats?
    let units: [MetaUnit]
    let units_positions: [MetaPosition]?
    let carry_units: [String]?
    let traits: [MetaTrait]?
    let strategy: MetaStrategy?
    let variations: MetaVariations?
    let augments: [String]?
    let carry_item_holders: [MetaHolder]?
    let units_stats: [MetaUnitStats]?
    let carousel_priority: [String]?
    let play_conditions: [MetaCondition]?
    let display_patch: String?
    let rank: String?
    let region: String?
    let sourceURL: URL?
    var authored: AuthoredGuide? = nil
    var publishedPlan: PublishedMetaPlan? = nil
    var id: String { (publishedPlan != nil ? "opgg:" : authored == nil ? "blitz:" : "hexa:") + comp_id }
    var tier: String { stats.flatMap { [1:"S",2:"A",3:"B",4:"C",5:"D"][$0.tier] } ?? "—" }
    var style: String {
        switch strategy?.type {
        case "fast_8": return "Fast 8"
        case "fast_9": return "Fast 9"
        case "fast_10": return "Fast 10"
        case "standard": return "Standard"
        case "slow_roll_5", "roll_5": return "Reroll niveau 5"
        case "slow_roll_6", "roll_6": return "Reroll niveau 6"
        case "slow_roll_7", "roll_7": return "Reroll niveau 7"
        default: return (strategy?.type ?? "Flexible").replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    func economy(at stage: Stage) -> String {
        if let plan = authored?.stages[stage.rawValue] { return plan }
        let type = strategy?.type ?? "standard"
        let reroll = type.hasPrefix("roll_") || type.hasPrefix("slow_roll_")
        if reroll {
            let target = type.last.map(String.init) ?? "6"
            switch stage {
            case .opening: return "Garde les copies de tes unités clés. Vise progressivement 10 puis 20 PO ; évite les relances dispersées."
            case .early: return "Construis ton économie vers 30 à 50 PO. Garde tes porteurs temporaires et prépare le niveau " + target + "."
            case .mid: return "Au niveau " + target + ", conserve si possible 50 PO et relance l’excédent pour les unités à trois étoiles. Stabilise plus tôt si tu perds trop de PV."
            case .transition: return "Vérifie tes copies et la concurrence. Continue les relances au niveau " + target + " tant que les améliorations clés restent atteignables."
            case .late: return "Après les trois étoiles prioritaires, investis dans les niveaux et ajoute les unités de soutien du plateau final."
            case .end: return "Dépense ta réserve pour les dernières améliorations et adapte le placement à l’adversaire que tu risques de rencontrer."
            }
        }
        switch stage {
        case .opening: return "Repère habituel : niveau 4 au 2-1 si ton ouverture le justifie. Joue tes meilleures unités deux étoiles et construis les premiers paliers d’intérêts."
        case .early: return "Repère habituel : niveau 5 vers le 2-5. Développe l’économie sans multiplier les relances et garde une première ligne solide."
        case .mid: return "Repère habituel : niveau 6 au 3-2. Vise 50 PO quand ton plateau le permet ; dépense pour stabiliser si tes PV chutent."
        case .transition: return type == "fast_9" || type == "fast_10" ? "Prépare le niveau 8 avec un plateau stable et conserve l’économie pour le niveau 9. Une montée rapide dépend de tes PV et de ton or." : "Prépare le niveau 8 vers 4-1 ou 4-2, puis cherche les carries et tanks deux étoiles du plateau cible."
        case .late: return "Stabilise les unités clés avant d’investir au niveau supérieur. Consulte les variantes 8 et 9 pour choisir les soutiens disponibles."
        case .end: return "Utilise l’or restant pour les dernières améliorations. Revois le côté de ton carry, les menaces adverses et la protection de ta première ligne."
        }
    }
    var url: URL { URL(string: "https://blitz.gg/tft/comps/" + slug)! }
    func title(_ reference: ReferenceData?) -> String {
        if let publishedPlan { return publishedPlan.name }
        if let title = authored?.title { return title }
        let carries = (carry_units ?? []).prefix(2).map { key in reference?.entries.first { $0.id == "champion:" + key }?.name ?? key }
        return carries.isEmpty ? slug.replacingOccurrences(of: "-", with: " ").capitalized : carries.joined(separator: " · ")
    }
    func variants(for stage: Stage) -> [MetaVariant] {
        let key = String(stage.rawValue.prefix(1))
        if let matches = variations?.stages?[key], !matches.isEmpty { return Array(matches.prefix(3)) }
        if stage == .opening || stage == .early { return Array((variations?.early ?? []).prefix(3)) }
        return []
    }
}
struct MetaPack: Codable {
    let data: [MetaComp]
    var retrievedAt: String?
    var set: String?
    var patch: String?
    static func decode(_ data: Data) throws -> MetaPack {
        guard data.count <= 20_000_000 else { throw DataIssue.invalid("Réponse trop volumineuse.") }
        let pack = try JSONDecoder().decode(Self.self, from: data)
        guard !pack.data.isEmpty, Set(pack.data.map(\.id)).count == pack.data.count,
              pack.data.allSatisfy({ comp in
                  guard let stats = comp.stats, comp.authored == nil else { return false }
                  return (1...8).contains(stats.avg_placement) && (0...1).contains(stats.top_4_percent) &&
                  comp.slug.range(of: #"^[a-z0-9-]+$"#, options: .regularExpression) != nil &&
                  !comp.units.isEmpty && Set(comp.units.map(\.name)).count == comp.units.count &&
                  (comp.units_positions ?? []).allSatisfy { (0..<28).contains($0.board_position) }
              }) else { throw DataIssue.invalid("Les compositions reçues sont incomplètes.") }
        return pack
    }
}
@MainActor final class MetaStore: ObservableObject {
    @Published private(set) var live: PatchSnapshot?
    @Published private(set) var archives: [PatchSnapshot] = []
    @Published private(set) var selection = PatchSelection()
    @Published private(set) var refreshing = false
    @Published private(set) var message: String?
    @Published private(set) var archiveMessage: String?
    @Published private(set) var experimental: ReferenceData?
    @Published private(set) var experimentalHistory: [ReferenceData] = []
    @Published private(set) var pbeCheckedAt: Date?
    @Published private(set) var pbeMessage: String?
    private var pbeBusy = false
    private var lastPBEAttempt: Date?
    @Published private(set) var euwVersion: String?
    private let feedURL: URL?
    @Published private(set) var partnerGuides: ExperimentalGuides? {
        didSet { checkedPBEVersion = nil }
    }
    @Published private var partnerRadar: MetaRadarSnapshot?
    @Published private(set) var publicMeta: OPGGMetaSnapshot?
    @Published private(set) var publicMetaCheckedAt: Date?
    @Published private(set) var publicMetaError: String?
    @Published private(set) var loadingRadarPage = false
    @Published private(set) var radarPageError: String?
    private var loadedRadarCursors: Set<String> = []
    let context: UltimateContext?
    private let directory: URL
    private var lastAttempt: Date?

    init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("HexaTFT")
        experimental = Self.bundle("pbe-reference")
        context = Self.bundle("ultimate-context")
        let livePack: MetaPack? = Self.bundle("live-meta")
        if let livePack {
            live = PatchSnapshot(pack: livePack, reference: Self.bundle("live-reference"), provider: "Riot · CommunityDragon")
        }
        feedURL = DragonFeed.bundledEndpoint("HexaMetaService")
        publicMeta = read("opgg-meta.json")
        if feedURL != nil {
            partnerGuides = read("partner-pbe.json")
            partnerRadar = read("partner-radar.json")
        }
        if let legacy = Self.loadBundledSnapshot(packName: "meta", referenceName: "reference") {
            archives = [legacy]
        }
        if let previous: MetaPack = read("meta-cache.json"), let legacy = archives.first,
           previous.patch == legacy.pack.patch && previous.set == legacy.pack.set {
            archives = [PatchSnapshot(pack: previous, reference: legacy.reference)]
        }
        if let saved: [PatchSnapshot] = read("patch-archives.json") {
            let bundled = archives
            archives = saved + bundled.filter { snapshot in !saved.contains(where: { $0.id == snapshot.id }) }
        }
        if let saved: PatchSnapshot = read("patch-live.json") {
            if live == nil || (saved.pack.retrievedAt ?? "") >= (live?.pack.retrievedAt ?? "") {
                if let bundled = live, bundled.id != saved.id, !archives.contains(where: { $0.id == bundled.id }) { archives.insert(bundled, at: 0) }
                live = saved
            } else if saved.id != live?.id, !archives.contains(where: { $0.id == saved.id }) {
                archives.insert(saved, at: 0)
            }
        }
        if let saved: ReferenceData = read("patch-pbe.json"),
           (experimental?.retrievedAt ?? "") <= saved.retrievedAt { experimental = saved }
        experimentalHistory = read("patch-pbe-history.json") ?? []
        if let previous: ReferenceData = read("patch-pbe-previous.json"),
           !experimentalHistory.contains(where: { $0.version == previous.version }) {
            experimentalHistory.append(previous)
        }
        if let saved: PatchSelection = read("patch-selection.json") { selection = saved }
    }

    var archive: PatchSnapshot? { archives.first { $0.id == selection.archiveID } ?? archives.first }
    var pack: MetaPack? {
        switch selection.channel {
        case .live: return live?.pack
        case .pbe: return nil
        case .archives: return archive?.pack
        }
    }
    var reference: ReferenceData? {
        switch selection.channel {
        case .live: return live?.reference
        case .pbe: return experimental
        case .archives: return archive?.reference
        }
    }
    var sourceName: String {
        switch selection.channel {
        case .live: return live?.sourceName ?? "Riot"
        case .archives: return archive?.sourceName ?? "Archive"
        case .pbe: return activePBECatalogue?.provider ?? "CommunityDragon"
        }
    }
    var radar: MetaRadarSnapshot {
        guard let partnerRadar, partnerRadar.isValid(for: live?.reference, patch: live?.pack.patch) else { return .bundled }
        return partnerRadar
    }
    func catalogue(for radar: MetaRadarSnapshot) -> PatchSnapshot? {
        ([live].compactMap { $0 } + archives).first {
            $0.pack.patch == radar.patch && $0.pack.set == radar.set && radar.matches($0.reference)
        }
    }
    func nativeGuide(for entry: MetaObservation, in radar: MetaRadarSnapshot,
                     catalogue: PatchSnapshot?) -> MetaComp? {
        guard let id = entry.relatedGuide, let reference = catalogue?.reference, radar.matches(reference) else { return nil }
        if entry.guideID != nil, let guide = catalogue?.pack.data.first(where: { $0.comp_id == id }),
           !guide.finalBoard.positions.isEmpty, Set(entry.champions).isSubset(of: guide.finalBoard.keys) {
            return guide
        }
        guard radar.patch == "18.6", reference.version.hasPrefix("16.22.") else { return nil }
        return LiveGuideCatalogue.guides.first { $0.comp_id == id && LiveGuideCatalogue.isCompatible($0, with: reference) }
    }
    var activePartnerGuides: ExperimentalGuides? {
        guard partnerGuides?.revision == experimental?.version,
              partnerGuides?.set == experimental?.entries.first?.set else { return nil }
        return partnerGuides
    }
    private var checkedPBEVersion: String?
    private var checkedPBECatalogue: PatchSnapshot?
    private var activePBECatalogue: PatchSnapshot? {
        guard let experimental, let guides = activePartnerGuides else { return nil }
        if checkedPBEVersion != experimental.version {
            checkedPBECatalogue = guides.validatedCatalogue(for: experimental)
            checkedPBEVersion = experimental.version
        }
        return checkedPBECatalogue
    }
    private var pbeCatalogueVersion: String?
    private var pbeCatalogue: [MetaComp] = []
    var editorialComps: [MetaComp] {
        if selection.channel == .pbe, let reference {
            if pbeCatalogueVersion != reference.version {
                pbeCatalogue = LiveGuideCatalogue.experimentalGuides(reference: reference)
                pbeCatalogueVersion = reference.version
            }
            return pbeCatalogue
        }
        guard pack?.patch == "18.6",
              let reference, reference.version.hasPrefix("16.22.") else { return [] }
        return LiveGuideCatalogue.guides.filter { LiveGuideCatalogue.isCompatible($0, with: reference) }
    }
    var comps: [MetaComp] {
        let entries = selection.channel == .pbe ? activePBECatalogue?.pack.data : pack?.data
        let published = selection.channel == .live ? currentPublicMeta?.pack.data ?? [] : []
        return ((entries ?? []) + published).sorted { ($0.stats?.avg_placement ?? .infinity) < ($1.stats?.avg_placement ?? .infinity) }
    }

    var currentPublicMeta: OPGGMetaSnapshot? {
        guard let publicMeta, let reference = live?.reference,
              publicMeta.pack.set == reference.entries.first?.set,
              publicMeta.pack.patch == live?.pack.patch,
              euwVersion.map({ $0.split(separator: ".").prefix(2).joined(separator: ".") == publicMeta.build }) != false,
              reference.version.hasPrefix(publicMeta.build + ".") else { return nil }
        return publicMeta
    }

    func select(_ channel: PatchSelection.Channel, archiveID: String? = nil) {
        selection = PatchSelection(channel: channel, archiveID: archiveID ?? selection.archiveID)
        try? save(selection, to: "patch-selection.json")
    }

    func report(_ message: String?) { archiveMessage = message }

    func importArchive(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 20_000_000 else {
                throw DataIssue.invalid("Taille maximale de 20 Mo.")
            }
            let snapshot = try JSONDecoder().decode(PatchSnapshot.self, from: Data(contentsOf: url))
            _ = try MetaPack.decode(JSONEncoder().encode(snapshot.pack))
            guard let patch = snapshot.pack.patch, let set = snapshot.pack.set, !patch.isEmpty, !set.isEmpty,
                  let reference = snapshot.reference, !reference.entries.isEmpty, Set(reference.entries.map(\.set)) == Set([set]),
                  snapshot.id != live?.id, !archives.contains(where: { $0.id == snapshot.id }) else {
                throw DataIssue.invalid("Version déjà présente ou Codex incompatible avec le set de l’instantané.")
            }
            let ids = Set(reference.entries.map(\.id))
            guard snapshot.pack.data.allSatisfy({ comp in
                comp.units.allSatisfy { ids.contains("champion:" + $0.name) } &&
                comp.slug.range(of: #"^[a-z0-9-]+$"#, options: .regularExpression) != nil
            }) else { throw DataIssue.invalid("Unités ou identifiants de composition invalides.") }
            let next = archives + [snapshot]
            try save(next, to: "patch-archives.json")
            archives = next
            select(.archives, archiveID: snapshot.id)
            archiveMessage = "Patch \(patch) archivé."
        } catch { archiveMessage = error.localizedDescription }
    }

    func autoRefresh() async {
        guard lastAttempt.map({ Date().timeIntervalSince($0) >= 300 }) ?? true else { return }
        await refresh(reference: live?.reference)
    }

    func refresh(reference _: ReferenceData?) async {
        guard !refreshing else { return }
        refreshing = true; message = nil; lastAttempt = Date()
        defer { refreshing = false }
        async let publicResult = OPGGMetaSnapshot.fetch()
        do {
            let euw = try await DragonFeed.liveEUW()
            euwVersion = euw
            let branch = euw.split(separator: ".").prefix(2).joined(separator: ".")
            guard branch.range(of: #"^[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil else {
                throw DataIssue.invalid("Riot n’a pas fourni de version EUW exploitable.")
            }
            let current = live
            let currentBranch = current?.reference?.version.split(separator: ".").prefix(2).joined(separator: ".")
            if currentBranch != branch {
                let revision = try await DragonFeed.build(at: branch)
                let reference = try await DragonFeed.reference(branch: branch, revision: revision, set: nil)
                let patch = Self.patchNumber(for: branch, set: reference.entries.first?.set)
                let pack = MetaPack(data: [], retrievedAt: Date().ISO8601Format(), set: reference.entries.first?.set, patch: patch)
                try install(PatchSnapshot(pack: pack, reference: reference, provider: "Riot · CommunityDragon"))
            }
            await updatePublicMeta(publicResult, branch: branch)
            guard !Task.isCancelled else { return }
            guard let feedURL else { return }
            let data = try await DragonFeed.get(feedURL, max: 20_000_000)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let feed = try decoder.decode(PartnerFeed.self, from: data)
            if let pbe = feed.pbe {
                guard pbe.guides.allSatisfy({ $0.source.scheme == "https" && !$0.provider.isEmpty && !$0.title.isEmpty }),
                      Set(pbe.guides.map(\.id)).count == pbe.guides.count else {
                    throw DataIssue.invalid("Guides PBE du flux incompatibles.")
                }
                try save(pbe, to: "partner-pbe.json")
                partnerGuides = pbe
            }
            if let offered = feed.live {
                let validated = try MetaPack.decode(JSONEncoder().encode(offered.pack))
                guard let reference = live?.reference, let source = offered.provider, !source.isEmpty,
                      validated.set == reference.entries.first?.set, validated.patch?.isEmpty == false,
                      validated.data.allSatisfy({ $0.display_patch == branch }) else {
                    throw DataIssue.invalid("Le catalogue partenaire ne correspond pas au build EUW.")
                }
                let ids = Set(reference.entries.map(\.id))
                guard validated.data.allSatisfy({ $0.units.allSatisfy { ids.contains("champion:" + $0.name) } }) else {
                    throw DataIssue.invalid("Les champions du flux ne correspondent pas au Codex.")
                }
                try install(PatchSnapshot(pack: validated, reference: reference, provider: source))
                message = "Catalogue du flux actualisé."
            }
            if let offered = feed.radar, offered.isValid(for: live?.reference, patch: live?.pack.patch),
               !radar.matches(live?.reference) || offered.retrievedAt > radar.retrievedAt || (partnerRadar == nil && offered.retrievedAt == radar.retrievedAt) {
                try save(offered, to: "partner-radar.json")
                partnerRadar = offered
                loadedRadarCursors.removeAll()
                radarPageError = nil
            }
        } catch {
            if !Task.isCancelled { message = "\(error.localizedDescription) Les dernières fiches restent disponibles." }
        }
    }

    static func patchNumber(for branch: String, set: String?) -> String? {
        // During set 18, TFT 18.1–18.7 map to client branches 16.17–16.23.
        guard set == "18", branch.hasPrefix("16."),
              let minor = Int(branch.dropFirst(3)), (17...23).contains(minor) else { return nil }
        return "18.\(minor - 16)"
    }

    private func updatePublicMeta(_ result: OPGGMetaSnapshot.Page?, branch: String) async {
        guard !Task.isCancelled, let reference = live?.reference else { return }
        publicMetaCheckedAt = .now
        guard let result,
              let snapshot = result.snapshot(reference: reference, branch: branch, patch: live?.pack.patch) else {
            publicMetaError = "OP.GG ne fournit pas de relevé compatible pour le moment."
            return
        }
        if let published = currentPublicMeta, published.publishedAt > snapshot.publishedAt { return }
        do {
            // The provider identifies both the set and current TFT patch. On a new set,
            // use this only after Riot and CommunityDragon agree on the client branch.
            if let current = live, current.pack.patch == nil {
                var pack = current.pack
                pack.patch = snapshot.pack.patch
                try install(PatchSnapshot(pack: pack, reference: reference, provider: current.provider))
            }
            try save(snapshot, to: "opgg-meta.json")
            publicMeta = snapshot
            publicMetaError = nil
        } catch {
            publicMetaError = "Impossible d’enregistrer le relevé OP.GG."
        }
    }

    func loadNextRadarPage() async {
        guard !loadingRadarPage, let cursor = radar.nextCursor,
              let feedURL, var components = URLComponents(url: feedURL, resolvingAgainstBaseURL: false) else { return }
        components.queryItems = [URLQueryItem(name: "cursor", value: cursor)]
        guard let url = components.url else { return }
        let current = radar
        loadingRadarPage = true
        radarPageError = nil
        defer { loadingRadarPage = false }
        do {
            let data = try await DragonFeed.get(url, max: 20_000_000)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard !Task.isCancelled, radar.retrievedAt == current.retrievedAt, radar.nextCursor == cursor else { return }
            guard let page = try decoder.decode(PartnerFeed.self, from: data).radar,
                  page.isValid(for: live?.reference, patch: live?.pack.patch),
                  var merged = current.merging(page, after: cursor) else {
                throw DataIssue.invalid("La page suivante ne correspond pas au relevé affiché.")
            }
            if let next = merged.nextCursor, loadedRadarCursors.contains(next) { merged.nextCursor = nil }
            try save(merged, to: "partner-radar.json")
            loadedRadarCursors.insert(cursor)
            partnerRadar = merged
        } catch {
            if !Task.isCancelled { radarPageError = error.localizedDescription }
        }
    }

    private func install(_ updated: PatchSnapshot) throws {
        if let current = live, current.id != updated.id, (!current.pack.data.isEmpty || current.pack.patch == "18.6") {
            let next = [current] + archives.filter { $0.id != current.id && $0.id != updated.id }
            try save(next, to: "patch-archives.json")
            archives = next
        }
        try save(updated, to: "patch-live.json")
        live = updated
    }

    func autoRefreshPBE() async {
        guard !pbeBusy, lastPBEAttempt.map({ Date().timeIntervalSince($0) >= 600 }) ?? true else { return }
        pbeBusy = true; lastPBEAttempt = Date()
        defer { pbeBusy = false }
        do {
            let revision = try await DragonFeed.build(at: "pbe")
            if experimental?.version != revision {
                let next = try await DragonFeed.reference(branch: "pbe", revision: revision, set: nil)
                let checkedRevision = try await DragonFeed.build(at: "pbe")
                guard checkedRevision == revision else { throw DataIssue.invalid("Une nouvelle révision PBE est en cours de publication.") }
                if let experimental, !experimentalHistory.contains(where: { $0.version == experimental.version }) {
                    let next = [experimental] + experimentalHistory
                    try save(next, to: "patch-pbe-history.json")
                    experimentalHistory = next
                }
                try save(next, to: "patch-pbe.json")
                experimental = next
            }
            pbeCheckedAt = Date()
            pbeMessage = nil
        } catch { if !Task.isCancelled { pbeMessage = error.localizedDescription } }
    }

    private static func bundle<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private static func loadBundledSnapshot(packName: String, referenceName: String) -> PatchSnapshot? {
        guard let url = Bundle.main.url(forResource: packName, withExtension: "json"),
              let data = try? Data(contentsOf: url), let pack = try? MetaPack.decode(data) else { return nil }
        return PatchSnapshot(pack: pack, reference: bundle(referenceName))
    }
    private func read<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private func save<T: Encodable>(_ value: T, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}

// Source boards can include summoned structures that are not purchasable champions.
extension ReferenceEntry {
    static func boardEntity(_ key: String) -> ReferenceEntry {
        let names = ["DA_Elderwood18_Lifeblossom": "Fleur de vie", "DA_Elderwood18_StonebarkTree": "Rochécorce", "DA_Elderwood18_Protector": "Protecteur de Fonds-de-bois"]
        return ReferenceEntry(id: "entity:" + key, name: names[key] ?? "Invocation", kind: "entity", set: "18", cost: 0, description: "Élément invoqué présent dans le plateau de la source.", imageURL: "")
    }
}
