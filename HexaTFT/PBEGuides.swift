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
                Text("Aucun guide de composition vérifié pour ce build. Les exemples ci-dessous appartiennent à une révision antérieure.").font(.subheadline)
                if let date = meta.pbeCheckedAt { Text("Build vérifié le \(date.formatted())").font(.caption).foregroundStyle(.secondary) }
                NavigationLink("Voir le Codex PBE") { CodexView() }
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
