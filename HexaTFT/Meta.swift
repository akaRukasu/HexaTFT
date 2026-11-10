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
struct MetaComp: Codable, Identifiable {
    let comp_id: String
    let slug: String
    let stats: MetaStats
    let units: [MetaUnit]
    let units_positions: [MetaPosition]?
    let carry_units: [String]?
    let traits: [MetaTrait]?
    let strategy: MetaStrategy?
    let variations: MetaVariations?
    let augments: [String]?
    let carry_item_holders: [MetaHolder]?
    let units_stats: [MetaUnitStats]?
    let display_patch: String?
    let rank: String?
    let region: String?
    var id: String { "blitz:" + comp_id }
    var tier: String { [1:"S",2:"A",3:"B",4:"C",5:"D"][stats.tier] ?? "—" }
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
        guard !pack.data.isEmpty, pack.data.count <= 250, Set(pack.data.map(\.id)).count == pack.data.count,
              pack.data.allSatisfy({ comp in
                  (1...8).contains(comp.stats.avg_placement) && (0...1).contains(comp.stats.top_4_percent) &&
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
    @Published private(set) var previousExperimental: ReferenceData?
    @Published private(set) var pbeCheckedAt: Date?
    @Published private(set) var pbeMessage: String?
    private var pbeBusy = false
    private var lastPBEAttempt: Date?
    let context: UltimateContext?
    private let directory: URL
    private var lastAttempt: Date?

    init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("HexaTFT")
        experimental = Self.bundle("pbe-reference")
        context = Self.bundle("ultimate-context")
        live = Self.loadBundledSnapshot(packName: "live-meta", referenceName: "live-reference")
        if let legacy = Self.loadBundledSnapshot(packName: "meta", referenceName: "reference") {
            archives = [legacy]
        }
        if let previous: MetaPack = read("meta-cache.json"), let legacy = archives.first,
           previous.patch == legacy.pack.patch && previous.set == legacy.pack.set {
            archives = [PatchSnapshot(pack: previous, reference: legacy.reference)]
        }
        if let saved: [PatchSnapshot] = read("patch-archives.json") {
            for snapshot in saved where !archives.contains(where: { $0.id == snapshot.id }) { archives.append(snapshot) }
        }
        if let saved: PatchSnapshot = read("patch-live.json"),
           live == nil || (saved.pack.retrievedAt ?? "") >= (live?.pack.retrievedAt ?? "") { live = saved }
        if let saved: ReferenceData = read("patch-pbe.json"),
           (experimental?.retrievedAt ?? "") <= saved.retrievedAt { experimental = saved }
        previousExperimental = read("patch-pbe-previous.json")
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
    var comps: [MetaComp] { (pack?.data ?? []).sorted { $0.stats.avg_placement < $1.stats.avg_placement } }

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
        guard lastAttempt.map({ Date().timeIntervalSince($0) > 600 }) ?? true else { return }
        await refresh(reference: live?.reference)
    }

    func refresh(reference _: ReferenceData?) async {
        guard !refreshing else { return }
        refreshing = true; message = nil; lastAttempt = Date()
        defer { refreshing = false }
        do {
            let request = URLRequest(url: URL(string: "https://blitz.gg/tft/comps")!, timeoutInterval: 25)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw DataIssue.invalid("Blitz est temporairement indisponible.")
            }
            var pack = try Self.parseBlitz(data)
            guard let set = pack.set, let patch = pack.patch,
                  let version = pack.data.first?.display_patch, version.range(of: #"^[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil,
                  pack.data.allSatisfy({ $0.display_patch == version }) else {
                throw DataIssue.invalid("La version des compositions reçues est incohérente.")
            }
            let current = live
            let reference: ReferenceData
            if let current, current.pack.set == set, current.pack.patch == patch,
               current.pack.data.first?.display_patch == version, let same = current.reference {
                reference = same
            } else {
                let euw = try await DragonFeed.liveEUW()
                guard euw.hasPrefix(version + ".") else {
                    throw DataIssue.invalid("Le catalogue et la version EUW des ressources ne concordent pas encore.")
                }
                let build = try await DragonFeed.build(at: version)
                reference = try await DragonFeed.reference(branch: version, revision: build, set: set)
            }
            let known = Set(reference.entries.filter { $0.kind == "champion" }.map { String($0.id.dropFirst(9)) })
            guard pack.data.allSatisfy({ $0.units.allSatisfy { known.contains($0.name) } }) else {
                throw DataIssue.invalid("Les champions reçus ne correspondent pas au Codex de ce patch.")
            }
            pack.retrievedAt = ISO8601DateFormatter().string(from: Date())
            let updated = PatchSnapshot(pack: pack, reference: reference)
            if let current, current.id != updated.id, !archives.contains(where: { $0.id == current.id }) {
                let next = [current] + archives
                try save(next, to: "patch-archives.json")
                archives = next
            }
            try save(updated, to: "patch-live.json")
            live = updated
            message = "Compositions actualisées."
        } catch { if !Task.isCancelled { message = "\(error.localizedDescription) Les dernières fiches restent disponibles." } }
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
                if let experimental {
                    try save(experimental, to: "patch-pbe-previous.json")
                    previousExperimental = experimental
                }
                try save(next, to: "patch-pbe.json")
                experimental = next
            }
            pbeCheckedAt = Date()
            pbeMessage = nil
        } catch { if !Task.isCancelled { pbeMessage = error.localizedDescription } }
    }

    nonisolated static func parseBlitz(_ data: Data) throws -> MetaPack {
        guard data.count <= 20_000_000, let html = String(data: data, encoding: .utf8) else {
            throw DataIssue.invalid("Réponse Blitz illisible.")
        }
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        func match(_ pattern: String) throws -> String? {
            let regex = try NSRegularExpression(pattern: pattern)
            return regex.firstMatch(in: html, range: range).map { ns.substring(with: $0.range(at: 1)) }
        }
        let regex = try NSRegularExpression(pattern: #"<script([^>]*)>(.*?)</script>"#, options: [.dotMatchesLineSeparators])
        guard let hit = regex.matches(in: html, range: range).first(where: {
            let attrs = ns.substring(with: $0.range(at: 1))
            return attrs.contains("data-sveltekit-fetched") && attrs.contains("/analyzed_comps?")
        }), let payload = try JSONSerialization.jsonObject(with: Data(ns.substring(with: hit.range(at: 2)).utf8)) as? [String: Any],
            let body = payload["body"] as? String else { throw DataIssue.invalid("Le format Blitz a changé.") }
        var result = try MetaPack.decode(Data(body.utf8))
        result.patch = try match(#"Patch ([0-9]+\.[0-9]+[a-z]?)"#)
        result.set = try match(#"TFT Set ([0-9]+)"#)
        return result
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
