import SwiftUI

// Prepared study material. No input from a running match is collected.
struct GuideBrief {
    let comp: MetaComp
    let reference: ReferenceData?
    let stage: Stage
    var primary: String? { comp.publishedPlan?.primaryUnit ?? comp.carry_units?.first }
    var tank: String? { comp.publishedPlan?.frontline ?? comp.carry_units?.dropFirst().first }
    var reroll: Bool { (comp.strategy?.type ?? "").contains("roll_") }
    func name(_ key: String?) -> String { key.flatMap { reference?.champion(key: $0)?.name } ?? "le porteur du guide" }
    var checkpoints: [String] {
        switch stage {
        case .opening:
            return ["Joue les améliorations trouvées ; le plateau affiché est un exemple d’ouverture.",
                    "Prépare les objets de \(name(primary)) sur un porteur compatible, sans vendre une unité qui reste dans le plateau final.",
                    "Au 2-3, revois tes paires et les paliers d’intérêts avant le prochain niveau."]
        case .early:
            return ["Garde les copies du noyau et compare les porteurs temporaires au plateau cible.",
                    "Au 3-1, prépare les achats de la transition : unités à garder, remplaçants et objets à transférer.",
                    "Évite de répartir un même ensemble d’objets sur plusieurs porteurs que tu devras vendre."]
        case .mid:
            return ["Vérifie ensemble les étoiles du porteur et celles de la première ligne.",
                    reroll ? "Compte les copies avant d’engager l’économie dans les trois étoiles ; le niveau de relance est celui du guide." : "Au 3-5, prépare les places réservées à \(name(primary)) et aux soutiens du plateau final.",
                    "Réserve une partie des composants à la première ligne ; trois objets de dégâts ne remplacent pas un tank solide."]
        case .transition:
            return ["Le plateau affiché est une cible de transition, pas une obligation de tout acheter au même combat.",
                    "Prépare \(name(primary)) et sa protection avant de vendre le porteur temporaire. Garde une copie si elle est nécessaire au noyau.",
                    reroll ? "Au 4-2, revois les copies manquantes et les unités contestées avant de poursuivre les relances." : "Au 4-2, réévalue les améliorations clés avant d’économiser pour le niveau suivant."]
        case .late:
            return ["Compare ton noyau amélioré à la variante finale : carry, tank, puis soutiens utiles.",
                    "Un porteur coûteux à une étoile ne garantit pas un plateau plus fort qu’un porteur temporaire amélioré.",
                    "Au 5-5, prépare les dernières améliorations et les objets restants avant d’investir dans une unité de luxe."]
        case .end:
            return ["Le plateau final décrit une direction ; conserve les améliorations qui rendent ton plateau cohérent.",
                    "Consulte la protection du carry et l’espacement indiqués par le guide avant les derniers combats.",
                    "Après la partie, ouvre Analyse pour comparer le plateau réellement terminé à ce plan."]
        }
    }
    var spend: String {
        if stage == .opening || stage == .early { return "Construis les intérêts quand le plateau le permet. Une dépense doit avoir une destination : niveau utile, paire ou amélioration précise." }
        if reroll { return "Le plan reroll vise les copies du noyau au niveau adapté. L’économie est un moyen ; si le plateau ne tient plus, le repère de 50 PO ne doit pas empêcher une stabilisation." }
        return "Cherche d’abord les améliorations du carry et du tank. Le passage au niveau suivant se prépare avec un plateau stabilisé ; le chiffre du niveau ne suffit pas à justifier la dépense."
    }
    var alternatives: [(String, String)] {
        [("Départ solide", "Conserve les unités améliorées et les intérêts ; prépare progressivement les places du plateau cible."),
         ("Besoin de stabiliser", "Révise les paires et les objets du noyau avant de chercher une fin de partie plus chère."),
         ("Copies manquantes", comp.authored?.pivot ?? "Consulte les variantes et garde un porteur temporaire équipé. Réévalue les copies disponibles avant de poursuivre un champion contesté.")]
    }
}

struct GuidePlaybook: View {
    @GuideReference private var reference: ReferenceData?
    let comp: MetaComp
    let stage: Stage
    let board: GuideBoard
    private var brief: GuideBrief { GuideBrief(comp: comp, reference: reference, stage: stage) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Panel {
                Label("Les décisions à préparer · " + stage.rawValue, systemImage: "list.bullet.clipboard.fill").font(.headline).foregroundStyle(.mint)
                ForEach(Array(brief.checkpoints.enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .top, spacing: 10) {
                        Text(String(index + 1)).font(.caption.bold()).frame(width: 24,height: 24).background(.mint.opacity(0.12),in:Circle()).foregroundStyle(.mint)
                        Text(text).font(.subheadline)
                    }
                }
                DisclosureGroup("Quand dépenser ?") { Text(brief.spend).font(.subheadline).padding(.top,6) }
                DisclosureGroup("Trois chemins à étudier avant de jouer") {
                    ForEach(brief.alternatives, id: \.0) { title, detail in
                        VStack(alignment: .leading,spacing: 4) { Text(title).font(.subheadline.bold()).foregroundStyle(hexaGold); Text(detail).font(.caption) }.padding(.vertical,6)
                    }
                }
                Text("Repères pédagogiques Hexa. Le guide ne lit pas ta partie et ne choisit pas une branche à ta place.").font(.caption2).foregroundStyle(.secondary)
            }.accessibilityIdentifier("guide-decision-brief")
            Panel {
                Label("Répartir les objets", systemImage: "diamond.fill").font(.headline).foregroundStyle(hexaGold)
                ForEach(Array(comp.units.filter { !($0.items ?? []).isEmpty }.enumerated()), id: \.offset) { _, unit in
                    HStack(alignment: .top,spacing: 12) {
                        if let entry = reference?.champion(key: unit.name) { EntryIcon(entry: entry,size: 38) }
                        VStack(alignment: .leading,spacing: 5) {
                            Text(brief.name(unit.name)).font(.subheadline.bold())
                            ItemIcons(keys: unit.items ?? [],size: 25)
                            Text(unit.name == brief.primary ? "Porteur principal · vise l’amélioration prévue avant les ajouts de luxe." : unit.name == brief.tank ? "Protection du noyau · prépare aussi ses objets et ses étoiles." : "Porteur secondaire · conserve d’abord les objets nécessaires au noyau.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical,4)
                }
                Text("Les objets affichés forment un ensemble cible, pas un ordre de fabrication mesuré. Touche le portrait du plateau pour les recettes, les effets et les alternatives disponibles.").font(.caption).foregroundStyle(.secondary)
                if !board.itemTargets.isEmpty { Label("Transferts temporaires détaillés au-dessus", systemImage: "arrow.right.arrow.left").font(.caption).foregroundStyle(.mint) }
            }.accessibilityIdentifier("guide-item-distribution")
        }
    }
}

struct SessionPracticeCard: View {
    @EnvironmentObject private var tracker: TrackerStore
    @EnvironmentObject private var coach: AnalystStore
    var body: some View {
        if let account = tracker.state.selected, let goal = coach.state.goals[account], goal.set == tracker.profile?.currentSet {
            Panel {
                Label("Mon objectif préparé · Set \(goal.set)",systemImage:"target").font(.headline).foregroundStyle(.mint)
                Text(goal.topic.title).font(.title3.bold()); Text(goal.topic.practice).font(.subheadline)
                Text("Exercice choisi avant la session · bilan après les parties terminées.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
