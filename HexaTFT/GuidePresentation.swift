import Foundation

struct GuideBoard {
    let units: [MetaUnit]
    let positions: [MetaPosition]
    let sourceLabel: String
    let sample: Int?
    let isFinal: Bool
    var keys: Set<String> { Set(units.map(\.name)) }
}
struct ChampionLoadout {
    let items: [String]
    let target: String
    let isProjected: Bool
    var hasItems: Bool { !items.isEmpty }
}
extension MetaComp {
    var finalBoard: GuideBoard {
        GuideBoard(units: units, positions: units_positions ?? [], sourceLabel: authored == nil ? "Plateau final de référence" : "Plateau cible Hexa", sample: stats?.nb_games, isFinal: true)
    }
    func board(from variant: MetaVariant, label: String) -> GuideBoard {
        let keys = Set(variant.units.map(\.name))
        func valid(_ positions: [MetaPosition]) -> Bool {
            !positions.isEmpty && Set(positions.map(\.unit_api_name)) == keys &&
            Set(positions.map(\.board_position)).count == positions.count &&
            positions.allSatisfy { (0..<28).contains($0.board_position) }
        }
        var positions = variant.units_positions ?? []
        if !valid(positions) { positions = [] }
        var source = label
        // Stage samples do not always carry coordinates. Reuse coordinates only
        // when an observed level board contains exactly the same units.
        if positions.isEmpty, !keys.isEmpty {
            for level in (variations?.levels?.keys.map { $0 } ?? []).sorted(by: { (Int($0) ?? 0) < (Int($1) ?? 0) }) {
                if let match = variations?.levels?[level]?.first(where: {
                    Set($0.units.map(\.name)) == keys && valid($0.units_positions ?? [])
                }) {
                    positions = match.units_positions ?? []
                    source += " · placement observé au niveau " + level
                    break
                }
            }
        }
        return GuideBoard(units: variant.units, positions: positions, sourceLabel: source, sample: variant.nb_boards, isFinal: false)
    }
    func guideBoards(stage: Stage) -> [GuideBoard] {
        let stageKey = authored == nil ? String(stage.rawValue.prefix(1)) : stage.rawValue
        if let variants = variations?.stages?[stageKey]?.filter({ !$0.units.isEmpty }), !variants.isEmpty {
            return Array(variants.prefix(3)).map { board(from: $0, label: "Exemple du stade " + stageKey + "") }
        }
        if stage == .opening || stage == .early {
            let level = stage == .opening ? "4" : "5"
            let variants = variations?.levels?[level]?.filter { !$0.units.isEmpty } ?? []
            if !variants.isEmpty { return Array(variants.prefix(3)).map { board(from: $0, label: "Exemple d’ouverture niveau " + level + "") } }
            let early = (variations?.early ?? []).filter { !$0.units.isEmpty }
            if !early.isEmpty { return Array(early.prefix(3)).map { board(from: $0, label: "Ouverture observée") } }
        }
        // Never present an empty sample as a playable board or invent positions.
        return [GuideBoard(units: units, positions: units_positions ?? [], sourceLabel: "Pas de variante pour ce stade · plateau final de référence", sample: stats?.nb_games, isFinal: true)]
    }
    func guideBoards(level: String) -> [GuideBoard] {
        Array((variations?.levels?[level] ?? []).filter { !$0.units.isEmpty }.prefix(3)).map { board(from: $0, label: (authored == nil ? "Plateau observé niveau " : "Plateau proposé niveau ") + level) }
    }
    func loadout(for key: String, on board: GuideBoard) -> ChampionLoadout {
        if let equipped = board.units.first(where: { $0.name == key })?.items, !equipped.isEmpty {
            return ChampionLoadout(items: equipped, target: key, isProjected: false)
        }
        if let targetItems = units.first(where: { $0.name == key })?.items, !targetItems.isEmpty {
            return ChampionLoadout(items: targetItems, target: key, isProjected: !board.isFinal)
        }
        let possible = (carry_item_holders ?? []).filter { holder in
            holder.stats.contains { $0.early_game_carry_api_name == key } &&
            !(units.first { $0.name == holder.end_game_carry_api_name }?.items ?? []).isEmpty
        }
        // Several possible carries need an explicit choice; don't assign one silently.
        if possible.count == 1, let carry = possible.first {
            return ChampionLoadout(items: units.first { $0.name == carry.end_game_carry_api_name }?.items ?? [], target: carry.end_game_carry_api_name, isProjected: true)
        }
        return ChampionLoadout(items: [], target: key, isProjected: false)
    }
    func alternativeTrios(for key: String, excluding items: [String]) -> [MetaUnitStats.Trio] {
        var seen: Set<String> = [items.sorted().joined(separator: "|")]
        return (units_stats?.first { $0.name == key }?.item_trios ?? []).filter { trio in
            guard !trio.item_api_names.isEmpty else { return false }
            return seen.insert(trio.item_api_names.sorted().joined(separator: "|")).inserted
        }.prefix(3).map { $0 }
    }
}
extension ReferenceEntry {
    var effectText: String {
        let effect = description.components(separatedBy: "\nRecette :").first ?? description
        if effect.isEmpty, kind == "item", set == "18" { return Set18ItemEffects.text[id] ?? "" }
        return effect
    }
    var itemCategory: String? {
        let categories = ["Attack": "Dégâts d’attaque", "Magic": "Puissance", "Defense": "Protection", "Mana": "Mana", "Support": "Soutien"]
        for (key, label) in categories.sorted(by: { $0.key < $1.key }) {
            if itemTags?.contains(where: { $0.hasSuffix("." + key) }) == true { return label }
        }
        return nil
    }
}

private enum Set18ItemEffects {
    static let text: [String: String] = [
        "item:DA_AdaptiveHelm": "Augmente les gains de mana. Le bonus secondaire dépend du rôle du porteur et donne des résistances aux tanks et combattants.",
        "item:DA_Bloodthirster": "Soigne le porteur quand il inflige des dégâts et le protège à faibles PV. Utile sur un carry de mêlée.",
        "item:DA_BlueBuff": "Accélère les lancements répétés. À privilégier sur les champions dont le coût en mana est bas.",
        "item:DA_Crownguard": "Protège en début de combat avec un bouclier, puis renforce la puissance. Convient à un lanceur de sorts de première ligne.",
        "item:DA_DragonsClaw": "Renforce la résistance magique. Prioritaire face aux plateaux qui infligent surtout des dégâts de sort.",
        "item:DA_EdgeOfNight": "Protège brièvement le porteur lorsque ses PV chutent. Sert à donner une seconde fenêtre d’attaque à un carry de mêlée.",
        "item:DA_GuinsoosRageblade": "Fait monter la vitesse d’attaque pendant le combat. Prioritaire lorsque le porteur peut rester actif longtemps.",
        "item:DA_Quicksilver": "Protège temporairement des effets de contrôle. Utile quand un carry perdrait plusieurs attaques à cause d’un étourdissement.",
        "item:DA_GargoyleStoneplate": "Augmente les résistances du porteur lorsque plusieurs ennemis le ciblent. Place-le sur le premier tank exposé.",
        "item:DA_GiantSlayer": "Amplifie les dégâts contre les champions de rôle tank.",
        "item:DA_HandOfJustice": "Combine dégâts et soin. Un substitut quand il faut à la fois survivre et infliger des dégâts.",
        "item:DA_HextechGunblade": "Une partie des dégâts du porteur soigne le porteur et un allié blessé.",
        "item:DA_InfinityEdge": "Permet aux compétences de bénéficier des coups critiques. À privilégier sur un carry physique.",
        "item:DA_JeweledGauntlet": "Permet aux compétences de critiquer. Un bon choix pour un carry qui inflige l’essentiel de ses dégâts avec son sort.",
        "item:DA_KrakensFury": "Récompense les attaques répétées. Donne à son porteur le temps de rester en vie pour en profiter.",
        "item:DA_LastWhisper": "Réduit l’armure de la cible et ouvre la voie aux dégâts physiques du reste de l’équipe.",
        "item:DA_Morellonomicon": "Les dégâts du porteur infligent une brûlure et réduisent les soins. Utile sur un champion qui touche plusieurs ennemis.",
        "item:DA_NashorsTooth": "Les attaques rendent du mana. Les attaques critiques en rendent davantage.",
        "item:DA_RabadonsDeathcap": "Donne de la puissance et de l’amplification des dégâts. Combine-la avec un objet de mana si le champion lance son sort trop tard.",
        "item:DA_RedBuff": "Ajoute de la vitesse d’attaque et applique une brûlure qui réduit les soins.",
        "item:DA_SpearOfShojin": "Les attaques rendent du mana supplémentaire. Fabrique-la pour lancer le premier sort plus tôt et le relancer plus souvent.",
        "item:DA_SpiritVisage": "Aide la première ligne à récupérer des PV pendant les combats prolongés.",
        "item:DA_SteadfastHeart": "Réduit les dégâts reçus, surtout tant que le porteur reste en bonne santé.",
        "item:DA_StrikersFlail": "Amplifie les dégâts quand le porteur enchaîne les critiques. Associe-le à une source de critiques sur les sorts si nécessaire.",
        "item:DA_SunfireCape": "Brûle les ennemis proches et réduit leurs soins. Place-la sur un tank qui reste au contact.",
        "item:DA_TitansResolve": "Gagne en efficacité pendant le combat lorsque le porteur attaque ou encaisse. Convient à un combattant capable de tenir au contact.",
        "item:DA_VoidStaff": "Réduit la résistance magique des cibles. Donne-le à un champion qui peut appliquer cet effet régulièrement.",
        "item:DA_WarmogsArmor": "Augmente les PV du porteur. Combine-la avec une source de résistances sur le tank principal."
    ]
}
