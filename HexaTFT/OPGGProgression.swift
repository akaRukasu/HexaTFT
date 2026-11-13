import Foundation

// An authored route towards the published roster, never an OP.GG timeline sample.
struct OPGGProgression {
    struct Step {
        let level: Int
        let board: GuideBoard
    }
    let steps: [Stage: Step]
    let levels: [Int: GuideBoard]

    init?(comp: MetaComp, reference: ReferenceData?) {
        guard let plan = comp.publishedPlan, let reference,
              reference.entries.first?.set == "18", let branch = comp.display_patch, reference.version.hasPrefix(branch + "."),
              !comp.units.isEmpty, comp.units.allSatisfy({ reference.champion(key: $0.name) != nil }),
              let final = comp.suggestedPublicBoard(reference: reference) else { return nil }
        let roster = Set(comp.units.map(\.name))
        let primary = plan.primaryUnit ?? comp.units.first?.name ?? ""
        let tank = plan.frontline
        let reroll = comp.strategy?.type?.contains("roll_") == true
        let rollLevel = min(7, max(5, plan.targetLevel ?? 6))
        let champions = Dictionary(uniqueKeysWithValues: reference.entries.filter { $0.kind == "champion" }.map { (String($0.id.dropFirst(9)), $0) })
        func entry(_ key: String) -> ReferenceEntry? { champions[key] }
        func cost(_ key: String) -> Int { entry(key)?.cost ?? 99 }
        func front(_ key: String) -> Bool { (entry(key)?.balance?["range"] ?? 1) <= 2 }
        func slots(_ key: String) -> Int { key == "DA_18_ElderDragon" ? 2 : 1 }
        let finalLevel = max(comp.units.reduce(0) { $0 + slots($1.name) }, plan.targetLevel ?? 0)
        let jungle = comp.units.contains { (entry($0.name)?.traitNames ?? []).contains("Jungle") }
        let eligible = reference.entries.filter {
            $0.kind == "champion" && $0.set == "18" && $0.id.hasPrefix("champion:DA_") &&
            (1...4).contains($0.cost) && !($0.traitNames ?? []).isEmpty &&
            (jungle || !($0.traitNames ?? []).contains("Jungle"))
        }.map { String($0.id.dropFirst(9)) }.sorted()

        // Prefer the opening of a Hexa guide for this carry. The later boards
        // are rebuilt from the actual published roster, not the template's endgame.
        let templates = LiveGuideCatalogue.guides.filter { LiveGuideCatalogue.isCompatible($0, with: reference) }
        func templateScore(_ guide: MetaComp) -> Int {
            let carries = guide.carry_units ?? []
            return (carries.first == primary ? 100 : carries.contains(primary) ? 60 : 0) +
                Set(guide.units.map(\.name)).intersection(roster).count
        }
        let template = templates.sorted {
            let lhs = templateScore($0), rhs = templateScore($1)
            return lhs == rhs ? $0.id < $1.id : lhs > rhs
        }.first.flatMap { templateScore($0) >= 60 ? $0 : nil }
        let opening = template?.guideBoards(stage: .opening).first?.units.map(\.name) ?? []
        let middle = template?.guideBoards(stage: .mid).first?.units.map(\.name) ?? []
        let physicalItems: Set<String> = ["DA_InfinityEdge", "DA_Deathblade", "DA_LastWhisper", "DA_KrakensFury", "DA_RunaansHurricane", "DA_GuinsoosRageblade", "DA_TitansResolve", "DA_Bloodthirster"]
        let magicItems: Set<String> = ["DA_VoidStaff", "DA_Morellonomicon", "DA_RabadonsDeathcap", "DA_ArchangelsStaff", "DA_JeweledGauntlet", "DA_SpearOfShojin", "DA_HextechGunblade"]
        let items = Set(comp.units.first { $0.name == primary }?.items ?? [])
        // A short-range caster such as Morgana still needs a magic item holder.
        let physical = primary.hasSuffix("_AD") || items.intersection(physicalItems).count > items.intersection(magicItems).count
        let carriers = physical ? (front(primary) ? ["DA_18_Akali_AD", "DA_18_Camille", "DA_18_Warwick"] :
            ["DA_18_Xayah", "DA_18_Varus", "DA_18_Caitlyn"]) : ["DA_Karma18", "DA_18_LeBlanc", "DA_18_Veigar"]
        let tanks = ["DA_18_Ornn", "DA_18_Leona", "DA_18_Yorick", "DA_18_Alistar", "DA_18_Sejuani"]

        func temporary(for target: String, candidates: [String]) -> String? {
            let curated = (template?.carry_item_holders ?? []).filter { $0.end_game_carry_api_name == target }
                .flatMap { $0.stats.map(\.early_game_carry_api_name) }
            // A unit kept in the final roster must not be sold to transfer items.
            return (curated + candidates).first { eligible.contains($0) && cost($0) <= 2 && !roster.contains($0) }
        }
        let carryHolder = temporary(for: primary, candidates: carriers)
        let tankHolder = tank.flatMap { temporary(for: $0, candidates: tanks) }
        var steps: [Stage: Step] = [:]
        var levels: [Int: GuideBoard] = [:]
        for stage in Stage.allCases {
            let level: Int
            let ceiling: Int
            switch stage {
            case .opening: level = reroll && rollLevel == 5 ? 3 : 4; ceiling = 2
            case .early: level = reroll && rollLevel == 5 ? 4 : 5; ceiling = 2
            case .mid: level = reroll && rollLevel == 5 ? 5 : 6; ceiling = 3
            case .transition: level = reroll ? rollLevel : 8; ceiling = 4
            case .late: level = 8; ceiling = 4
            case .end: level = finalLevel; ceiling = 7
            }
            if stage == .end || (stage == .late && finalLevel <= 8) {
                let step = Step(level: finalLevel, board: final)
                steps[stage] = step
                levels[finalLevel] = final
                continue
            }
            var selected: [String] = []
            var targets: [String: String] = [:]
            var used = 0
            func add(_ key: String?) {
                guard let key, !selected.contains(key), cost(key) <= ceiling, used + slots(key) <= level else { return }
                selected.append(key); used += slots(key)
            }
            if cost(primary) <= ceiling { add(primary) }
            else if let carryHolder { add(carryHolder); targets[carryHolder] = primary }
            if let tank, cost(tank) <= ceiling { add(tank) }
            else if let tank, let tankHolder, tankHolder != carryHolder { add(tankHolder); targets[tankHolder] = tank }
            let candidates = eligible.filter { cost($0) <= ceiling }
            while used < level {
                let existingTraits = selected.flatMap { entry($0)?.traitNames ?? [] }
                let frontlineNeeded = selected.filter { front($0) }.count < min(3, level / 2)
                func score(_ key: String) -> Int {
                    let traits = entry(key)?.traitNames ?? []
                    let synergy = traits.filter { existingTraits.contains($0) }.count
                    return (roster.contains(key) ? 40 : 0) + (opening.contains(key) ? 16 : 0) +
                        (middle.contains(key) ? 8 : 0) + synergy * 6 +
                        (frontlineNeeded && front(key) ? 25 : 0) - cost(key)
                }
                let next = candidates.filter { !selected.contains($0) && used + slots($0) <= level }
                    .map { (key: $0, score: score($0)) }.sorted {
                        $0.score == $1.score ? $0.key < $1.key : $0.score > $1.score
                    }.first?.key
                guard let next else { break }
                add(next)
            }
            guard !selected.isEmpty else { return nil }
            let units = selected.map { MetaUnit(name: $0, items: nil, star_level: nil) }
            targets = targets.filter { holder, target in
                selected.contains(holder) && !(comp.units.first { $0.name == target }?.items ?? []).isEmpty
            }
            let board = GuideBoard(units: units,
                positions: MetaComp.suggestedPositions(units: units, frontline: tank.flatMap { selected.contains($0) ? $0 : tankHolder }, reference: reference),
                sourceLabel: "Parcours proposé par Hexa · stade \(stage.rawValue) · placement indicatif",
                sample: nil, isFinal: false, itemTargets: targets, isSuggestedProgression: true)
            steps[stage] = Step(level: level, board: board)
            if levels[level] == nil { levels[level] = board }
        }
        self.steps = steps
        self.levels = levels
    }

    func advice(at stage: Stage, comp: MetaComp, reference: ReferenceData?) -> String {
        guard let step = steps[stage] else { return comp.economy(at: stage) }
        var text = comp.economy(at: stage)
        if comp.strategy?.type?.hasSuffix("roll_5") == true {
            if stage == .opening {
                text = "Reste niveau 3 au 2-1 sans acheter d’XP pour ce plan de reroll à 1 PO. Garde les copies du carry et joue les meilleures améliorations trouvées. Préserve les premiers paliers d’intérêts."
            } else if stage == .early {
                text = "Laisse l’XP naturelle t’amener au niveau 4. Conserve les copies prioritaires et construis l’économie vers 50 PO. Prépare le niveau 5 vers 3-2 pour chercher tes trois étoiles ; stabilise plus tôt si tes PV chutent."
            }
        }
        if stage == .mid, comp.strategy?.type?.hasSuffix("roll_7") == true {
            text = "Repère : niveau 6 au 3-2. Prépare le niveau 7 vers 3-5 ou 4-1 selon tes PV et ton or, puis cherche les copies du carry. Relance l’excédent au-dessus de 50 PO quand ton plateau est stable."
        }
        let name: (String) -> String = { reference?.champion(key: $0)?.name ?? $0 }
        let transfers = step.board.itemTargets.sorted { $0.key < $1.key }
        if !transfers.isEmpty {
            text += "\n\nObjets provisoires : " + transfers.map { name($0.key) + " → " + name($0.value) }.joined(separator: " ; ") + ". Garde une copie de remplacement avant de vendre un porteur."
        }
        if let carry = comp.publishedPlan?.primaryUnit, step.board.keys.contains(carry) {
            text += "\n\nPriorité : améliorer " + name(carry) + " et ta première ligne avant de poursuivre les niveaux."
        }
        return text
    }
}
