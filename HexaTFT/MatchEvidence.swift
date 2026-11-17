import Foundation

struct MatchItem: Codable, Identifiable, Hashable {
    let key: String
    let name: String
    let category: String?
    var imageURL: String? = nil
    var components: [String]? = nil
    var effect: String? = nil
    var id: String { key }
    var isComponent: Bool {
        category == "component" || key.hasPrefix("DA_Component_") || Self.componentKeys.contains(key)
    }
    var isComplete: Bool {
        guard !isComponent, let category else { return false }
        return ["core", "standard", "artifact", "radiant", "emblem", "support", "completed"].contains(category)
    }
    static let componentKeys: Set<String> = ["TFT_Item_BFSword", "TFT_Item_RecurveBow", "TFT_Item_NeedlesslyLargeRod", "TFT_Item_TearOfTheGoddess", "TFT_Item_ChainVest", "TFT_Item_NegatronCloak", "TFT_Item_GiantsBelt", "TFT_Item_SparringGloves", "TFT_Item_Spatula", "TFT_Item_FryingPan"]
}

extension TrackedMatch.Unit {
    var completeItems: [MatchItem] { (equipment ?? []).filter(\.isComplete) }
    var components: [MatchItem] { (equipment ?? []).filter(\.isComponent) }
    var unknownEquipment: Int { max(0, items.count - (equipment ?? []).filter { $0.isComplete || $0.isComponent }.count) }
    var displayName: String { name ?? key }
}

struct SeasonRecord: Codable, Identifiable {
    let id: String
    let number: String
    let ranks: [RiotProfile.Rank]
    var solo: RiotProfile.Rank? { ranks.first { $0.queue == "RANKED_TFT" } }
}

struct SeasonArchive: Codable, Identifiable {
    let set: Int
    let matches: [TrackedMatch]
    let checkedAt: Date
    let indexedGames: Int?
    let indexedTop4: Int?
    var id: Int { self.set }
}

struct AnalysisSummary {
    let matches: [TrackedMatch]
    var count: Int { matches.count }
    var average: Double { count == 0 ? 0 : Double(matches.map(\.placement).reduce(0,+)) / Double(count) }
    var top4: Int { matches.filter { $0.placement <= 4 }.count }
    var bottoms: Int { matches.filter { $0.placement >= 7 }.count }
    var wins: Int { matches.filter { $0.placement == 1 }.count }
    var top4Rate: Double { count == 0 ? 0 : Double(top4) / Double(count) }
    var interval: ClosedRange<Double> {
        guard count > 0 else { return 0...1 }
        let n = Double(count), z = 1.96, p = top4Rate
        let centre = (p + z*z/(2*n))/(1+z*z/n)
        let radius = z * sqrt(p*(1-p)/n + z*z/(4*n*n))/(1+z*z/n)
        return max(0,centre-radius)...min(1,centre+radius)
    }
}

struct AnalysisFinding: Identifiable {
    let id: String
    let title: String
    let fact: String
    let interpretation: String
    let exercise: String
    let limitation: String
    let evidence: [TrackedMatch]
    let category: TrainingTopic
}

enum TrainingTopic: String, Codable, CaseIterable, Identifiable {
    case stability, frontline, economy, coherence
    var id: String { rawValue }
    var title: String {
        switch self { case .stability: "Améliorer mes porteurs"; case .frontline: "Équiper ma première ligne"; case .economy: "Préparer ma stabilisation"; case .coherence: "Consolider mon noyau" }
    }
    var symbol: String {
        switch self { case .stability: "star.circle.fill"; case .frontline: "shield.lefthalf.filled"; case .economy: "circle.circle.fill"; case .coherence: "point.3.connected.trianglepath.dotted" }
    }
    var practice: String {
        switch self {
        case .stability: "Avant la session, repère les améliorations prioritaires du guide. Après chaque match, compare les étoiles du carry et du tank."
        case .frontline: "Prépare les objets du tank en parallèle de ceux du carry. Après le match, regarde quels porteurs ont effectivement reçu l’équipement."
        case .economy: "Étudie les conditions de dépense du guide avant de jouer. Après une sortie avec de l’or, note si cette réserve avait une destination prévue."
        case .coherence: "Choisis un noyau de traits et ses variantes avant la session. Compare ensuite les paliers réellement actifs sur le plateau final."
        }
    }
}

struct CarryCohort: Identifiable {
    let id: String
    let name: String
    let matches: [TrackedMatch]
    let oneStar: [TrackedMatch]
    let improved: [TrackedMatch]
    var twoStar: [TrackedMatch] { matches.filter { match in match.units.contains { $0.key == id && $0.stars == 2 && $0.completeItems.count >= 2 } } }
    var threeStar: [TrackedMatch] { matches.filter { match in match.units.contains { $0.key == id && ($0.stars ?? 0) >= 3 && $0.completeItems.count >= 2 } } }
}

struct MatchAnalyst {
    let matches: [TrackedMatch]
    let set: Int?
    let patch: String?
    init(matches: [TrackedMatch], set: Int?, patch: String? = nil, limit: Int = 30) {
        self.set = set; self.patch = patch
        var seen: Set<String> = []
        self.matches = Array(matches.sorted { $0.timestamp > $1.timestamp }.filter {
            $0.queue == 1100 && $0.set == set && (patch == nil || $0.patch == patch) &&
                (1...8).contains($0.placement) && seen.insert($0.id).inserted
        }.prefix(limit))
    }
    var summary: AnalysisSummary { AnalysisSummary(matches: matches) }
    var cohorts: [CarryCohort] {
        var groups: [String: [(TrackedMatch, TrackedMatch.Unit)]] = [:]
        for match in matches {
            var seen: Set<String> = []
            for unit in match.units where unit.completeItems.count >= 2 && seen.insert(unit.key).inserted {
                groups[unit.key, default: []].append((match,unit))
            }
        }
        return groups.map { key, values in
            CarryCohort(id: key, name: values.first?.1.displayName ?? key, matches: values.map(\.0),
                        oneStar: values.filter { $0.1.stars == 1 }.map(\.0),
                        improved: values.filter { ($0.1.stars ?? 0) >= 2 }.map(\.0))
        }.sorted { $0.matches.count == $1.matches.count ? $0.id < $1.id : $0.matches.count > $1.matches.count }
    }
    var findings: [AnalysisFinding] {
        var result: [AnalysisFinding] = []
        let weak = matches.filter { match in match.placement > 4 && match.units.contains { $0.stars == 1 && $0.completeItems.count >= 2 } }
        if !weak.isEmpty {
            result.append(AnalysisFinding(id: "stability", title: "Des porteurs équipés encore 1 étoile",
                fact: "\(weak.count) sorties hors du top 4 avec au moins un porteur 1 étoile et deux objets complets ou plus.",
                interpretation: "La puissance du plateau peut être limitée par ses améliorations. Examine les copies et les dépenses avant d’investir dans sa fin de partie.",
                exercise: TrainingTopic.stability.practice, limitation: "Les boutiques, le banc et le nombre de relances ne sont pas connus. Un porteur secondaire peut expliquer ce constat.", evidence: weak, category: .stability))
        }
        let gold = matches.filter { $0.placement > 4 && ($0.goldLeft ?? -1) >= 20 }
        if !gold.isEmpty {
            result.append(AnalysisFinding(id: "economy", title: "De l’or encore disponible à la sortie",
                fact: "\(gold.count) défaites avec au moins 20 PO à l’élimination.",
                interpretation: "Un point à revoir : cet or pouvait-il renforcer le plateau un ou deux combats plus tôt ? Une sortie imprévue reste possible.",
                exercise: TrainingTopic.economy.practice, limitation: "L’or final ne permet pas de dater tes dépenses ni de conclure que tu as relancé trop tard.", evidence: gold, category: .economy))
        }
        let front = matches.filter { match in
            match.placement > 4 && match.units.contains { $0.completeItems.count >= 3 } &&
            match.units.contains { unit in unit.equipment != nil && (unit.stars ?? 0) >= 2 && unit.items.isEmpty && (unit.range ?? 99) <= 1 && (unit.cost ?? 0) >= 3 }
        }
        if !front.isEmpty {
            result.append(AnalysisFinding(id: "frontline", title: "Une première ligne à examiner",
                fact: "\(front.count) défaites associent un porteur à trois objets complets et une unité de mêlée améliorée à 3 PO ou plus sans objet.",
                interpretation: "Vérifie si la répartition de l’équipement protégeait suffisamment les porteurs de dégâts. Une unité de mêlée n’est pas nécessairement le tank principal.",
                exercise: TrainingTopic.frontline.practice, limitation: "Le rôle exact et l’ordre d’obtention des composants ne sont pas toujours fournis. Ce signal n’est pas un verdict.", evidence: front, category: .frontline))
        }
        return result
    }
    func findings(for match: TrackedMatch) -> [AnalysisFinding] {
        MatchAnalyst(matches: [match], set: match.set).findings
    }
    var overview: String {
        guard !matches.isEmpty else { return "Importe des parties classées terminées pour obtenir une analyse personnelle." }
        let s = summary
        return "Sur \(s.count) parties : \(s.top4) top 4 et \(s.bottoms) places 7–8. " +
            (findings.isEmpty ? "Aucun signal récurrent de ces règles ne ressort. Explore tes porteurs et les contre-exemples." : "Les priorités ci-dessous sont reliées à tes matchs ; ouvre les preuves avant de conclure.")
    }
}
