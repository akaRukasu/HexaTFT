import SwiftUI

struct PBEGuide: Identifiable {
    let name: String
    let core: [String]
    let style: String
    let opener: String
    let transition: String
    let risk: String
    let sourceSlug: String
    var id: String { sourceSlug }
    var source: URL { URL(string: "https://mobalytics.gg/tft/comps-guide/" + sourceSlug)! }
    static let augustSet18: [Self] = [
        .init(name: "Ahri · Sett Floraison", core: ["Ahri", "Sett", "Sivir", "Ashe"], style: "Fast 8",
              opener: "Une ouverture Floraison permet de préparer la transition. Yorick peut garder les objets défensifs en attendant Sett.",
              transition: "Au niveau 8, stabilise autour d’Ahri et Sett. Les objets de puissance restent sur Ahri ou Zyra, tandis que Sivir et Ashe ouvrent une branche AD.",
              risk: "Le plan demande de conserver assez d’or pour réunir plusieurs unités chères. La branche AD et la branche AP requièrent des objets différents.",
              sourceSlug: "blossom-3GPQCU22Yg7ot21ySOx6oL2t9Zb"),
        .init(name: "Aphelios · Lux Sylvestre", core: ["Aphelios", "Lux", "Lillia", "Gnar"], style: "Fast 8",
              opener: "Cherche une première ligne Sylvestre et conserve un porteur provisoire pour les objets d’attaques répétées.",
              transition: "Au niveau 8, répartis l’équipement entre Aphelios en arrière et Lillia en première ligne. Ajuste le nombre d’unités Sylvestres selon les paliers que tu peux réellement atteindre.",
              risk: "Un plateau qui atteint le bon palier de trait peut encore manquer de dégâts si Aphelios n’est pas amélioré.",
              sourceSlug: "elderwood-3GPSrl1mdvWbwjkesuBNjDFFKvx"),
        .init(name: "Rengar · Kha’Zix Unrivaled", core: ["Rengar", "Kha’Zix", "Hecarim", "Ezreal"], style: "Reroll niveau 7",
              opener: "Garde les copies de Rengar et Kha’Zix si tu envisages le duo. Vérifie la présence de l’optimisation Unrivaled avant de t’y engager.",
              transition: "Au niveau 7, vise les améliorations à trois étoiles en protégeant ton économie. Hecarim apporte le temps nécessaire aux deux porteurs.",
              risk: "Le plan dépend de l’optimisation et du nombre de copies disponibles. Si le duo est trop contesté, stabilise avec les améliorations déjà trouvées.",
              sourceSlug: "unrivaled-3HOkuCvHq4MMnqTveMC1xcFMX2y"),
        .init(name: "Cassiopeia · Fiddlesticks", core: ["Cassiopeia", "Fiddlesticks", "Rammus"], style: "Reroll niveau 7",
              opener: "Construis une première ligne peu coûteuse et prépare des objets AP pour Cassiopeia.",
              transition: "Cherche Cassiopeia et ses soutiens au niveau 7. Priorise une première ligne qui tient assez longtemps pour laisser Cassiopeia relancer ses sorts.",
              risk: "La version à unités doublées dépend de l’optimisation associée. Sans elle, les doublons peuvent coûter un palier de synergie.",
              sourceSlug: "double-trouble-cass-3HpzhQPssAQ1jkFGBKnP9PsmZSC")
    ]
}
struct PBEGuideList: View {
    @EnvironmentObject private var meta: MetaStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Panel {
                Label("Révision expérimentale", systemImage: "flask").font(.headline)
                if meta.activePartnerGuides == nil {
                    Text("Aucun guide vérifié dans le flux pour ce build. Les exemples historiques restent disponibles ci-dessous.").font(.subheadline)
                }
                if let date = meta.pbeCheckedAt { Text("Build vérifié le \(date.formatted())").font(.caption).foregroundStyle(.secondary) }
                NavigationLink("Voir le Codex PBE") { CodexView() }
                if let reference = meta.experimental {
                    NavigationLink("Explorer les synergies du build") { PBELabView(reference: reference) }
                }
            }
            if let active = meta.activePartnerGuides {
                Text("Guides du build \(active.revision)").font(.headline)
                Text("Collecte \(active.retrievedAt)").font(.caption).foregroundStyle(.secondary)
                ForEach(active.guides) { guide in
                    NavigationLink {
                        List {
                            Section("Expérimental · \(active.revision)") {
                                Text(guide.style)
                                Text(guide.core.joined(separator: " · "))
                                Text(guide.plan)
                                Link(guide.provider, destination: guide.source)
                            }
                        }.navigationTitle(guide.title)
                    } label: {
                        Panel {
                            Text(guide.title).font(.headline)
                            Text(guide.provider).font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }
            }
            Text("Les pistes du dernier guide PBE retrouvé").font(.headline)
            Text("Set 18 · 22 août 2026 · sélection éditoriale de Mobalytics. Hexa propose des repères de progression pour ces archétypes.").font(.caption).foregroundStyle(.secondary)
            ForEach(PBEGuide.augustSet18) { guide in
                NavigationLink {
                    List {
                        Section("PBE historique · Set 18 · 22 août 2026") {
                            LabeledContent("Style", value: guide.style)
                            Text(guide.core.joined(separator: " · "))
                            Text("Piste éditoriale sans taux de victoire ni échantillon publié pour cette version.").font(.caption)
                        }
                        Section("Préparer l’ouverture") { Text(guide.opener) }
                        Section("Construire la transition") { Text(guide.transition) }
                        Section("Conditions et risques") { Text(guide.risk) }
                        Section("Sources") {
                            Link("Tier list PBE datée", destination: URL(string: "https://mobalytics.gg/tft/guides/best-tft-pbe-comps")!)
                            Link("Guide du fournisseur, susceptible d’avoir évolué", destination: guide.source)
                        }
                    }.navigationTitle(guide.name)
                } label: {
                    Panel {
                        Text(guide.name).font(.headline)
                        Text(guide.style + " · " + guide.core.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain)
            }
        }
    }
}


struct PBELabView: View {
    let reference: ReferenceData
    @State private var query = ""
    private var groups: [ReferenceEntry] {
        reference.entries.filter {
            $0.kind == "trait" && ($0.traitThresholds ?? []).contains { $0 >= 2 } &&
            (query.isEmpty || $0.name.localizedStandardContains(query)) && !units(for: $0).isEmpty
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private func units(for trait: ReferenceEntry) -> [ReferenceEntry] {
        reference.entries.filter {
            $0.kind == "champion" && (1...7).contains($0.cost) && ($0.traitNames ?? []).contains(trait.name)
        }.sorted { ($0.cost, $0.name) < ($1.cost, $1.name) }
    }
    var body: some View {
        List {
            Section {
                Badge(text: "BUILD " + reference.version, color: hexaGold)
                Text("Atelier de théorie. Les paliers et les unités viennent de cette révision du client. Le regroupement sert à préparer un essai et ne mesure pas sa force en partie.").font(.caption)
            }
            ForEach(groups) { trait in
                NavigationLink {
                    let members = units(for: trait)
                    List {
                        Section("Paliers de la révision") {
                            Text((trait.traitThresholds ?? []).map(String.init).joined(separator: " · "))
                            Text(trait.description)
                        }
                        Section("Première ligne possible · portée courte") {
                            ForEach(members.filter { ($0.balance?["range"] ?? .infinity) <= 2 }) { row($0) }
                        }
                        Section("Arrière possible · portée longue") {
                            ForEach(members.filter { ($0.balance?["range"] ?? 0) > 2 }) { row($0) }
                        }
                        let missingRange = members.filter { $0.balance?["range"] == nil }
                        if !missingRange.isEmpty { Section("Portée non renseignée") { ForEach(missingRange) { row($0) } } }
                    }.navigationTitle(trait.name)
                } label: { LabeledContent(trait.name, value: "\(units(for: trait).count) unités") }
            }
        }.searchable(text: $query).navigationTitle("Atelier PBE")
    }
    private func row(_ entry: ReferenceEntry) -> some View {
        HStack {
            EntryIcon(entry: entry)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name).font(.headline)
                Text((entry.traitNames ?? []).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.cost) PO").font(.caption).foregroundStyle(hexaGold)
        }
    }
}



enum LiveGuideCatalogue {
    private typealias Cell = (Int, String)
    static let guides: [MetaComp] = [ahri, solar, nidalee, teemo, masterYi]

    static func isCompatible(_ comp: MetaComp, with reference: ReferenceData) -> Bool {
        let ids = Set(reference.entries.map(\.id))
        let levels = (comp.variations?.levels ?? [:]).values.flatMap { $0 }.flatMap(\.units)
        let backups = (comp.units_stats ?? []).flatMap { $0.item_trios ?? [] }.flatMap(\.item_api_names)
        return (comp.units + levels).allSatisfy { ids.contains("champion:" + $0.name) } &&
            ((comp.units.flatMap { $0.items ?? [] }) + backups).allSatisfy { ids.contains("item:" + $0) }
    }

    private static func make(_ slug: String, style: String, carries: [String], source: String,
                             levels: [(Int, [Cell])], stageLevels: [Int], builds: [String: [String]],
                             substitutes: [String: [String]], transfers: [String: String],
                             plan: AuthoredGuide) -> MetaComp {
        func layout(_ cells: [Cell]) -> MetaVariant {
            MetaVariant(units: cells.map { MetaUnit(name: $0.1, items: nil, star_level: nil) },
                        units_positions: cells.map { MetaPosition(board_position: $0.0, unit_api_name: $0.1) },
                        nb_boards: nil, avg_placement: nil)
        }
        let target = layout(levels.last?.1 ?? [])
        let boards = Dictionary(uniqueKeysWithValues: levels.map { ($0.0, layout($0.1)) })
        let stageBoards = zip(Stage.allCases, stageLevels).compactMap { stage, level in
            boards[level].map { (stage.rawValue, [$0]) }
        }
        return MetaComp(comp_id: slug, slug: slug, stats: nil,
                        units: target.units.map { MetaUnit(name: $0.name, items: builds[$0.name], star_level: nil) },
                        units_positions: target.units_positions, carry_units: carries, traits: nil,
                        strategy: MetaStrategy(type: style, level_stage: nil),
                        variations: MetaVariations(early: nil, flex_options: nil,
                            levels: Dictionary(uniqueKeysWithValues: boards.map { (String($0.key), [$0.value]) }),
                            stages: Dictionary(uniqueKeysWithValues: stageBoards)),
                        augments: nil, carry_item_holders: transfers.sorted(by: { $0.key < $1.key }).map { from, to in
                            MetaHolder(end_game_carry_api_name: to, stats: [.init(early_game_carry_api_name: from)])
                        },
                        units_stats: substitutes.sorted(by: { $0.key < $1.key }).map { key, items in
                            MetaUnitStats(name: key, item_trios: [.init(item_api_names: items, nb_boards: nil, avg_placement: nil, pick_rate: nil)])
                        },
                        carousel_priority: nil, play_conditions: nil, display_patch: "16.22", rank: nil,
                        region: "EUW", sourceURL: URL(string: source), authored: plan)
    }

    private static let ahri = make("hexa-ahri-zyra", style: "fast_8",
        carries: ["DA_18_Ahri", "DA_18_Zyra"],
        source: "https://mobalytics.gg/tft/guides/set-18-ahri-comps",
        levels: [
            (4, [(1,"DA_18_Rakan"), (3,"DA_18_Yorick"), (5,"DA_18_Ornn"), (23,"DA_Karma18")]),
            (5, [(1,"DA_18_Rakan"), (3,"DA_18_Yorick"), (5,"DA_18_Ornn"), (21,"DA_18_LeBlanc"), (24,"DA_Karma18")]),
            (6, [(1,"DA_18_Rakan"), (3,"DA_18_Yorick"), (5,"DA_18_Ornn"), (7,"DA_18_Alistar"), (21,"DA_18_LeBlanc"), (24,"DA_Karma18")]),
            (8, [(1,"DA_18_Rakan"), (3,"DA_18_Sett"), (5,"DA_18_Lillia"), (7,"DA_18_Yorick"), (11,"DA_Fiddlesticks18"), (21,"DA_18_Ahri"), (24,"DA_18_Zyra"), (27,"DA_Karma18")])
        ], stageLevels: [4,5,6,8,8,8],
        builds: [
            "DA_18_Ahri": ["DA_SpearOfShojin","DA_JeweledGauntlet","DA_RabadonsDeathcap"],
            "DA_18_Sett": ["DA_GargoyleStoneplate","DA_WarmogsArmor","DA_SpiritVisage"],
            "DA_18_Zyra": ["DA_VoidStaff","DA_Morellonomicon","DA_SpearOfShojin"]
        ],
        substitutes: [
            "DA_18_Ahri": ["DA_AdaptiveHelm","DA_JeweledGauntlet","DA_StrikersFlail"],
            "DA_18_Sett": ["DA_SteadfastHeart","DA_DragonsClaw","DA_WarmogsArmor"]
        ], transfers: ["DA_18_LeBlanc":"DA_18_Ahri","DA_18_Ornn":"DA_18_Sett"],
        plan: AuthoredGuide(title: "Ahri · Zyra", stages: [
            "2-1":"Monte 4 si tu peux aligner Karma et Yorick avec une première ligne améliorée. Garde les composants de mana pour l’arrivée de LeBlanc.",
            "2-5":"Ajoute LeBlanc pour garder les objets d’Ahri. Si Karma est à deux étoiles et LeBlanc à une seule, garde le plateau le plus fort.",
            "3-2":"Monte 6 et ajoute Alistar. Utilise Ornn pour fabriquer le premier objet défensif. Limite les relances si ta première ligne tient.",
            "4-1":"Monte 8 entre 4-1 et 4-2. Trouve Ahri et une première ligne avant de vendre LeBlanc ou Ornn. Priorise Ahri et Sett à deux étoiles.",
            "5-1":"Ajoute la réduction de résistance magique ou l’anti-soin sur Zyra si personne ne l’applique. Garde Fiddlesticks proche des premiers combats.",
            "6-1":"Écarte les deux carries si l’adversaire touche plusieurs cases et déplace Ahri vers le côté où sa bombe couvre le plus de cibles."
        ], conditions: "Départ AP avec au moins un composant de mana et une première ligne améliorée. Le plan préfère une montée au niveau 8 avec assez d’or pour relancer.",
           pivot: "Si Ahri est contestée, conserve LeBlanc améliorée le temps de trouver un autre carry AP. Garde les objets défensifs sur un tank deux étoiles tant que Sett reste à une étoile.",
           positioning: "Sett prend le premier contact. Ahri et Zyra couvrent deux zones différentes depuis l’arrière. Déplace Fiddlesticks sur le côté où son contrôle a le plus de valeur.",
           itemPlans: [
               "DA_18_Ahri":"Fabrique d’abord Shojin pour lancer plus tôt. Ajoute le Gantelet pour les critiques de sort, puis complète avec de la puissance.",
               "DA_18_Sett":"Commence par le Lithoplastron si Sett reçoit les premières attaques. Les PV de Warmog et le Visage spirituel prolongent le combat.",
               "DA_18_Zyra":"Réserve le Bâton du vide à l’équipe si elle manque de réduction magique. Fabrique Morellonomicon si l’adversaire se soigne beaucoup."
           ]))

    private static let solar = make("hexa-yunara-solaire", style: "slow_roll_6",
        carries: ["DA_18_Yunara", "DA_Karma18"],
        source: "https://mobalytics.gg/tft/guides/set-18-how-to-play-solar",
        levels: [
            (4, [(2,"DA_18_Yorick"), (4,"DA_18_Leona"), (21,"DA_18_Yunara"), (25,"DA_Karma18")]),
            (5, [(2,"DA_18_Yorick"), (4,"DA_18_Leona"), (6,"DA_18_Sejuani"), (21,"DA_18_Yunara"), (25,"DA_Karma18")]),
            (6, [(2,"DA_18_Yorick"), (4,"DA_18_Leona"), (6,"DA_18_Sejuani"), (21,"DA_18_Yunara"), (23,"DA_18_Kayle"), (25,"DA_Karma18")]),
            (7, [(2,"DA_18_Yorick"), (4,"DA_18_Leona"), (6,"DA_18_Sejuani"), (21,"DA_18_Yunara"), (23,"DA_18_Kayle"), (25,"DA_Karma18"), (27,"DA_18_LeBlanc")])
        ], stageLevels: [4,5,6,6,7,7],
        builds: [
            "DA_18_Yunara":["DA_InfinityEdge","DA_LastWhisper","DA_GiantSlayer"],
            "DA_18_Sejuani":["DA_GargoyleStoneplate","DA_WarmogsArmor","DA_DragonsClaw"],
            "DA_Karma18":["DA_BlueBuff","DA_JeweledGauntlet","DA_RabadonsDeathcap"]
        ],
        substitutes: [
            "DA_18_Yunara":["DA_InfinityEdge","DA_KrakensFury","DA_RedBuff"],
            "DA_Karma18":["DA_SpearOfShojin","DA_JeweledGauntlet","DA_NashorsTooth"]
        ], transfers: [:],
        plan: AuthoredGuide(title: "Yunara · Solaire", stages: [
            "2-1":"Conserve Karma, Yorick et Yunara si plusieurs copies arrivent tôt. Leona prend les coups et prépare le trait Solaire.",
            "2-5":"Ajoute Sejuani. Garde les copies de Leona et des unités à deux PO. Évite de dépenser l’or qui te permet de gagner un palier d’intérêts.",
            "3-2":"Monte 6 et active Solaire avec Kayle. Stabilise Yunara et Sejuani à deux étoiles avant de reconstituer ton économie.",
            "4-1":"Relance au niveau 6 autour de 50 PO lorsque les PV le permettent. Priorise Yunara et Sejuani si elles sont proches de trois étoiles.",
            "5-1":"Après les améliorations clés, monte 7 pour ajouter LeBlanc. Si Karma n’est pas améliorée, LeBlanc peut prendre les objets AP supplémentaires.",
            "6-1":"Décale Yunara loin des menaces directes et adapte le tank principal au côté où l’adversaire concentre ses dégâts."
        ], conditions: "Joue ce plan avec plusieurs copies de Yunara ou de Sejuani et des composants AD. Les unités trois étoiles renforcent le bénéfice d’équipe de Solaire.",
           pivot: "Si Yunara est trop contestée, stabilise à deux étoiles. Tu peux monter de niveau avec le noyau Solaire et faire porter les objets AD à une unité améliorée.",
           positioning: "Sejuani et Leona absorbent les premiers coups. Laisse de l’espace entre Yunara et Karma lorsque le lobby joue des sorts de zone.",
           itemPlans: [
               "DA_18_Yunara":"Lame d’infini pour les critiques. Dernier souffle est prioritaire si personne ne réduit l’armure adverse. Contre les gros tanks, complète avec Tueur de géants.",
               "DA_18_Sejuani":"Lithoplastron et PV pour tenir la première ligne. Préfère une protection magique si les autres plateaux reposent sur des sorts.",
               "DA_Karma18":"Priorise le mana si elle est déjà améliorée. Fabrique les objets de puissance avec les composants restants après Yunara et Sejuani."
           ]))

    private static let nidalee = make("hexa-nidalee-ap", style: "fast_8",
        carries: ["DA_Nidalee18_AP","DA_18_Sivir"],
        source: "https://teamfighttactics.leagueoflegends.com/en-us/news/game-updates/teamfight-tactics-patch-18-6/",
        levels: [
            (4, [(1,"DA_18_Rakan"), (3,"DA_18_Yorick"), (7,"DA_18_Akali_AD"), (24,"DA_Gromp18_AP")]),
            (5, [(1,"DA_18_Rakan"), (3,"DA_18_Yorick"), (5,"DA_Vi18"), (7,"DA_18_Akali_AD"), (24,"DA_Gromp18_AP")]),
            (6, [(1,"DA_18_Rakan"), (3,"DA_18_Yorick"), (5,"DA_Vi18"), (7,"DA_18_Akali_AD"), (10,"DA_Scuttlecrab18"), (24,"DA_Gromp18_AP")]),
            (8, [(0,"DA_18_Rakan"), (2,"DA_Vi18"), (4,"DA_Amumu18"), (6,"DA_18_MasterYi_AD"), (10,"DA_Nidalee18_AP"), (12,"DA_Sentinel18"), (22,"DA_18_Sivir"), (27,"DA_18_Ashe")])
        ], stageLevels: [4,5,6,8,8,8],
        builds: [
            "DA_Nidalee18_AP":["DA_Bloodthirster","DA_JeweledGauntlet","DA_TitansResolve"],
            "DA_Amumu18":["DA_GargoyleStoneplate","DA_WarmogsArmor","DA_SunfireCape"],
            "DA_18_Sivir":["DA_InfinityEdge","DA_LastWhisper","DA_KrakensFury"]
        ],
        substitutes: [
            "DA_Nidalee18_AP":["DA_HandOfJustice","DA_JeweledGauntlet","DA_Crownguard"],
            "DA_18_Sivir":["DA_InfinityEdge","DA_GiantSlayer","DA_RedBuff"]
        ], transfers: ["DA_Gromp18_AP":"DA_Nidalee18_AP","DA_Scuttlecrab18":"DA_Amumu18"],
        plan: AuthoredGuide(title: "Nidalee AP · Primitif", stages: [
            "2-1":"Ouvre avec une paire améliorée. Gromp AP tient les premiers objets de puissance si tu l’as trouvé.",
            "2-5":"Ajoute Vi pour préparer le noyau Primitif. Garde tes composants défensifs disponibles si aucun tank ne mérite encore les objets.",
            "3-2":"Monte 6. Carapateur peut garder le premier objet de tank. Si tu saignes des PV, améliore le plateau avant de continuer à économiser.",
            "4-1":"Monte 8 et vérifie que tu as la forme AP de Nidalee avant de déplacer son équipement. Cherche Vi et Sivir pour Primitif, ainsi que Maître Yi pour Adaptateur.",
            "5-1":"Si Ashe tarde à venir, joue un Chasseur amélioré en attendant. Utilise les composants AD sur Sivir après avoir équipé Nidalee et le tank.",
            "6-1":"Décale Nidalee derrière le tank du côté où elle survivra aux premiers sorts. Garde Sivir à l’arrière pour assurer les dégâts continus."
        ], conditions: "Privilégie ce plan avec des composants de soin et de puissance et assez d’économie pour trouver des unités à quatre PO.",
           pivot: "Si tu ne trouves pas la forme AP, conserve un porteur AP stable. Avec beaucoup de composants AD, Sivir peut devenir le porteur principal de la base Primitif.",
           positioning: "Amumu engage au centre. Nidalee commence derrière la première ligne pour éviter le premier focus. Place Sivir du côté le moins exposé.",
           itemPlans: [
               "DA_Nidalee18_AP":"Le soin aide la forme de mêlée à rester au contact. Le Gantelet apporte des critiques de sort. Si elle meurt avant de se stabiliser, fabrique l’option défensive en premier.",
               "DA_Amumu18":"Le premier objet doit lui permettre d’encaisser. Ajoute Cape solaire pour appliquer l’anti-soin au contact si personne ne l’applique déjà.",
               "DA_18_Sivir":"Dernier souffle soutient ses dégâts physiques. Adapte le troisième objet aux gros tanks ou aux besoins d’anti-soin de l’équipe."
           ]))

    private static let teemo = make("hexa-teemo-leblanc", style: "slow_roll_6",
        carries: ["DA_18_Teemo", "DA_18_LeBlanc"],
        source: "https://www.metastats.gg/en/tft/comps/invoker-teemo?bucket=diamond_plus&days=3&region=all",
        levels: [
            (4, [(1,"DA_18_Ornn"), (4,"DA_18_Kobuko"), (22,"DA_18_Veigar"), (26,"DA_18_Teemo")]),
            (5, [(1,"DA_18_Ornn"), (4,"DA_18_Kobuko"), (8,"DA_18_Alistar"), (22,"DA_18_Veigar"), (26,"DA_18_Teemo")]),
            (6, [(1,"DA_18_Ornn"), (4,"DA_18_Kobuko"), (8,"DA_18_Alistar"), (22,"DA_18_Veigar"), (24,"DA_18_LeBlanc"), (26,"DA_18_Teemo")]),
            (7, [(1,"DA_18_Hecarim"), (3,"DA_18_Alistar"), (5,"DA_18_Kobuko"), (9,"DA_18_Rammus"), (21,"DA_18_Veigar"), (24,"DA_18_LeBlanc"), (26,"DA_18_Teemo")]),
            (8, [(1,"DA_18_Hecarim"), (3,"DA_18_Alistar"), (5,"DA_18_Kobuko"), (9,"DA_18_Rammus"), (12,"DA_Sentinel18"), (21,"DA_18_Veigar"), (24,"DA_18_LeBlanc"), (26,"DA_18_Teemo")])
        ], stageLevels: [4,5,6,6,7,8],
        builds: [
            "DA_18_Teemo":["DA_SpearOfShojin","DA_JeweledGauntlet","DA_RabadonsDeathcap"],
            "DA_18_Alistar":["DA_GargoyleStoneplate","DA_WarmogsArmor","DA_SpiritVisage"],
            "DA_18_LeBlanc":["DA_VoidStaff","DA_Morellonomicon","DA_SpearOfShojin"]
        ],
        substitutes: ["DA_18_Teemo":["DA_BlueBuff","DA_JeweledGauntlet","DA_NashorsTooth"]],
        transfers: [:],
        plan: AuthoredGuide(title: "Teemo · LeBlanc", stages: [
            "2-1":"Garde les paires de Teemo et Kobuko. Ornn protège la première ligne pendant que Veigar active Ami de la forêt.",
            "2-5":"Ajoute Alistar dès qu’il améliore le plateau. Réserve les composants de mana et de puissance à ton premier carry amélioré.",
            "3-2":"Monte 6 et ajoute LeBlanc. Cherche Teemo et Alistar deux étoiles pour stabiliser avant les relances longues.",
            "4-1":"Au niveau 6, garde si possible 50 PO. Teemo trois étoiles est prioritaire, puis Alistar ou LeBlanc si les copies viennent naturellement.",
            "5-1":"Après les améliorations, monte 7 pour Hecarim et Rammus. Conserve Ornn amélioré jusqu’à ce que la transition renforce la première ligne.",
            "6-1":"Ajoute Sentinelle au niveau 8. Écarte Teemo et LeBlanc contre les dégâts de zone."
        ], conditions: "Privilégie un départ avec plusieurs copies de Teemo ou Alistar, du mana et une Baguette. Compte les copies contestées avant de t’engager.",
           pivot: "Si Teemo est loin de trois étoiles, arrête les relances avant de perdre ton économie. Garde LeBlanc comme relais AP et monte vers une unité à quatre PO.",
           positioning: "Alistar prend les premiers coups. Positionne Hecarim vers le groupe adverse. Garde Teemo sur le côté le plus protégé.",
           itemPlans: [
               "DA_18_Teemo":"Shojin accélère les sorts. Le Gantelet permet les critiques, puis Rabadon augmente la puissance.",
               "DA_18_Alistar":"Monte d’abord une protection fiable. Place le Lithoplastron sur Alistar s’il attire plusieurs ennemis.",
               "DA_18_LeBlanc":"Complète les besoins de l’équipe avec réduction magique et anti-soin avant de lui donner plus de mana."
           ]))

    private static let masterYi = make("hexa-yi-vi", style: "slow_roll_7",
        carries: ["DA_18_MasterYi_AD", "DA_Vi18"],
        source: "https://tactics.tools/team-compositions/top",
        levels: [
            (4, [(0,"DA_18_Yorick"), (3,"DA_18_Rakan"), (7,"DA_18_Akali_AD"), (23,"DA_Karma18")]),
            (5, [(0,"DA_18_Yorick"), (3,"DA_18_Rakan"), (5,"DA_Vi18"), (7,"DA_18_Akali_AD"), (23,"DA_Karma18")]),
            (6, [(0,"DA_18_Yorick"), (3,"DA_18_Rakan"), (5,"DA_Vi18"), (8,"DA_18_MasterYi_AD"), (12,"DA_18_Akali_AD"), (23,"DA_Karma18")]),
            (7, [(0,"DA_18_Yorick"), (3,"DA_18_Sett"), (5,"DA_Vi18"), (8,"DA_18_MasterYi_AD"), (12,"DA_Nidalee18_AP"), (23,"DA_Karma18"), (27,"DA_18_Sivir")]),
            (8, [(0,"DA_18_Yorick"), (2,"DA_18_Rakan"), (4,"DA_18_Sett"), (6,"DA_Vi18"), (8,"DA_18_MasterYi_AD"), (12,"DA_Nidalee18_AP"), (23,"DA_Karma18"), (27,"DA_18_Sivir")])
        ], stageLevels: [4,5,6,7,7,8],
        builds: [
            "DA_18_MasterYi_AD":["DA_GuinsoosRageblade","DA_EdgeOfNight","DA_KrakensFury"],
            "DA_Vi18":["DA_GargoyleStoneplate","DA_WarmogsArmor","DA_SunfireCape"],
            "DA_18_Sivir":["DA_InfinityEdge","DA_LastWhisper","DA_GiantSlayer"]
        ],
        substitutes: ["DA_18_MasterYi_AD":["DA_Quicksilver","DA_TitansResolve","DA_KrakensFury"]],
        transfers: ["DA_18_Akali_AD":"DA_18_MasterYi_AD"],
        plan: AuthoredGuide(title: "Maître Yi · Vi", stages: [
            "2-1":"Ouvre Fleur spirituelle avec Yorick et Karma. Akali peut porter des objets de mêlée si tu peux l’améliorer.",
            "2-5":"Ajoute Vi pour renforcer la première ligne. Garde les paires naturelles de Maître Yi.",
            "3-2":"Monte 6. Maître Yi AD rejoint le plateau dès qu’il peut se battre au contact sans perdre trop de PV.",
            "4-1":"Monte 7. Stabilise Yi et Vi à deux étoiles puis relance l’excédent d’or si les copies sont accessibles.",
            "5-1":"Priorise Yi trois étoiles puis Vi si elle est proche. Sivir prend les objets AD restants.",
            "6-1":"Ajoute Rakan après les améliorations. Place Yi derrière la première ligne, vers le côté où il peut attaquer en continu."
        ], conditions: "Bon départ avec des Arcs et plusieurs copies de Yi ou Vi. Vérifie la forme AD de Yi avant le transfert.",
           pivot: "Si Yi est contesté, stabilise à deux étoiles puis monte de niveau. Sivir peut reprendre le rôle de carry AD si elle est améliorée.",
           positioning: "Vi et Sett prennent le premier contact. Yi entre derrière eux, à l’écart du contrôle adverse le plus dangereux.",
           itemPlans: [
               "DA_18_MasterYi_AD":"Guinsoo et Kraken récompensent les combats longs. Fabrique Manteau de la nuit tôt si Yi se fait cibler immédiatement.",
               "DA_Vi18":"Priorise les résistances et les PV. Ajoute Cape solaire si l’équipe manque d’anti-soin.",
               "DA_18_Sivir":"Dernier souffle apporte la réduction d’armure. Complète avec des objets de dégâts physiques."
           ]))
}
