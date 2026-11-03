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
    struct Trio: Codable { let item_api_names: [String]; let nb_boards: Int? }
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
    @Published private(set) var pack: MetaPack?
    @Published private(set) var refreshing = false
    @Published private(set) var message: String?
    private let cache: URL
    init(directory: URL? = nil) {
        let directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("HexaTFT")
        cache = directory.appendingPathComponent("meta-cache.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let url = Bundle.main.url(forResource: "meta", withExtension: "json"), let data = try? Data(contentsOf: url) {
            pack = try? MetaPack.decode(data)
        }
        if let data = try? Data(contentsOf: cache), let saved = try? MetaPack.decode(data), saved.set == pack?.set { pack = saved }
    }
    var comps: [MetaComp] { (pack?.data ?? []).sorted { $0.stats.avg_placement < $1.stats.avg_placement } }
    func refresh(reference: ReferenceData?) async {
        guard !refreshing else { return }
        refreshing = true; message = nil
        defer { refreshing = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: URL(string: "https://blitz.gg/tft/comps")!)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 20_000_000,
                  let html = String(data: data, encoding: .utf8) else { throw DataIssue.invalid("Blitz ne répond pas pour le moment.") }
            let regex = try NSRegularExpression(pattern: #"<script([^>]*)>(.*?)</script>"#, options: [.dotMatchesLineSeparators])
            let ns = html as NSString
            var next: MetaPack?
            for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let attrs = ns.substring(with: match.range(at: 1))
                guard attrs.contains("data-sveltekit-fetched"), attrs.contains("/analyzed_comps?") else { continue }
                let body = Data(ns.substring(with: match.range(at: 2)).utf8)
                let wrapper = try JSONSerialization.jsonObject(with: body) as? [String: Any]
                if let text = wrapper?["body"] as? String { next = try MetaPack.decode(Data(text.utf8)) }
            }
            guard var value = next else { throw DataIssue.invalid("Le format de Blitz a changé. Les dernières fiches restent disponibles.") }
            let known = Set((reference?.entries ?? []).filter { $0.kind == "champion" }.map { String($0.id.dropFirst(9)) })
            guard value.data.allSatisfy({ $0.units.allSatisfy { known.contains($0.name) } }) else {
                throw DataIssue.invalid("Un nouveau set est disponible. Mets Hexa à jour pour récupérer ses champions.")
            }
            value.set = pack?.set
            // Read the visible patch, distinct from the provider's internal API patch.
            let patchRegex = try NSRegularExpression(pattern: #"Patch ([0-9]+\.[0-9]+)"#)
            if let m = patchRegex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) { value.patch = ns.substring(with: m.range(at: 1)) }
            value.retrievedAt = ISO8601DateFormatter().string(from: Date())
            let encoded = try JSONEncoder().encode(value)
            try encoded.write(to: cache, options: .atomic)
            pack = value; message = "Compositions actualisées."
        } catch { message = "Actualisation impossible : \(error.localizedDescription) Les fiches enregistrées restent consultables." }
    }
}

// Source boards can include summoned structures that are not purchasable champions.
extension ReferenceEntry {
    static func boardEntity(_ key: String) -> ReferenceEntry {
        let names = ["DA_Elderwood18_Lifeblossom": "Fleur de vie", "DA_Elderwood18_StonebarkTree": "Rochécorce", "DA_Elderwood18_Protector": "Protecteur de Fonds-de-bois"]
        return ReferenceEntry(id: "entity:" + key, name: names[key] ?? "Invocation", kind: "entity", set: "18", cost: 0, description: "Élément invoqué présent dans le plateau de la source.", imageURL: "")
    }
}
