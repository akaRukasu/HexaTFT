import SwiftUI

let hexaGold = Color(red: 0.96, green: 0.76, blue: 0.35)
let hexaNavy = Color(red: 0.025, green: 0.045, blue: 0.105)
struct HexaBrand: View {
    var body: some View {
        HStack(spacing: 12) {
            Image("HexaLogo").resizable().scaledToFit().frame(width: 62, height: 62).clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("HEXA").font(.title.bold()).tracking(5)
                Text("Ton prochain top 4 commence ici.").font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}
struct MetaView: View {
    @EnvironmentObject private var meta: MetaStore
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var favorites = false
    @State private var style = "Tous"
    @State private var sort = "Moyenne"
    @State private var gems = false
    private var styles: [String] { ["Tous"] + Set((meta.comps + meta.editorialComps).map(\.style)).sorted() }
    private var filtered: [MetaComp] {
        let comps = (meta.comps + meta.editorialComps).filter { comp in
            (!favorites || store.state.favorites.contains(comp.id)) &&
            (style == "Tous" || comp.style == style) &&
            (!gems || comp.stats.map { $0.nb_games >= 500 && $0.pick_rate <= 0.03 && $0.avg_placement < 4.5 } == true) &&
            (query.isEmpty || searchable(comp).localizedStandardContains(query))
        }
        return sort == "Top 4" ? comps.sorted { ($0.stats?.top_4_percent ?? -1) > ($1.stats?.top_4_percent ?? -1) } : comps
    }
    private func searchable(_ comp: MetaComp) -> String {
        let ids = Set(comp.units.flatMap { ["champion:" + $0.name] + ($0.items ?? []).map { "item:" + $0 } } +
            (comp.traits ?? []).map { "trait:" + $0.trait_api_name } + (comp.augments ?? []).map { "augment:" + $0 })
        let names = store.reference?.entries.filter { ids.contains($0.id) }.map(\.name) ?? []
        return ([comp.title(store.reference), comp.style, comp.rank ?? "", comp.region ?? "", comp.authored == nil ? meta.sourceName : "Hexa"] + names).joined(separator: " ")
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HexaBrand()
                PatchPicker()
                HStack {
                    if meta.selection.channel == .pbe {
                        Badge(text: "SET " + (meta.experimental?.entries.first?.set ?? "—"), color: hexaGold)
                        if let revision = meta.experimental?.version { Badge(text: "BUILD " + revision, color: .mint) }
                    } else {
                        Badge(text: "SET " + (meta.pack?.set ?? "—"), color: hexaGold)
                        Badge(text: "PATCH " + (meta.pack?.patch ?? meta.euwVersion ?? "—"), color: hexaGold)
                        Spacer()
                        Text("\(meta.comps.count + meta.editorialComps.count) guides").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if meta.selection.channel == .pbe {
                    PBEGuideList()
                } else {
                    if meta.selection.channel == .live, !favorites, !gems {
                        MetaRadarPreview(snapshot: meta.radar, reference: store.reference, query: query)
                    }
                    guideShelf
                }
                NavigationLink { SourcesView() } label: {
                    Label("Sources et méthodologie", systemImage: "globe")
                }.foregroundStyle(hexaGold)
            }.padding()
        }
        .background(hexaNavy).navigationTitle("Méta").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Champion, composition…")
        .refreshable { if meta.selection.channel == .live { await meta.refresh(reference: store.reference) } }
        .onChange(of: meta.selection) { _, _ in style = "Tous"; gems = false }
    }
    private var guideShelf: some View {
        Group {
            Text(meta.selection.channel == .archives ? "Guides archivés" : "Guides du patch").font(.title2.bold())
            if meta.selection.channel == .archives {
                Text(meta.sourceName + " · " + String((meta.pack?.retrievedAt ?? "").prefix(10)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !meta.comps.isEmpty || !meta.editorialComps.isEmpty {
                HStack {
                    if !meta.comps.isEmpty {
                        Picker("Style", selection: $style) { ForEach(styles, id: \.self) { Text($0).tag($0) } }
                        Picker("Trier", selection: $sort) { Text("Moyenne").tag("Moyenne"); Text("Top 4").tag("Top 4") }
                    }
                    Spacer()
                    Button { favorites.toggle() } label: { Image(systemName: favorites ? "star.fill" : "star") }
                        .accessibilityLabel(favorites ? "Afficher toutes les compos" : "Afficher les favoris")
                }
                ForEach(filtered) { comp in
                    NavigationLink { MetaDetail(comp: comp) } label: { MetaCard(comp: comp) }
                        .buttonStyle(.plain).accessibilityIdentifier("meta-card-" + comp.comp_id)
                }
                if filtered.isEmpty { ContentUnavailableView("Aucune composition", systemImage: "magnifyingglass", description: Text("Change la recherche ou les filtres.")) }
                if !meta.comps.isEmpty {
                    Toggle("Pépites de la méta", isOn: $gems)
                    if gems { Text("Fréquence ≤ 3 %, moyenne < 4,50 et au moins 500 parties.").font(.caption).foregroundStyle(.secondary) }
                }
            }
            if meta.selection.channel == .live, !favorites, !gems, query.isEmpty,
               let latest = meta.archives.first(where: { !$0.pack.data.isEmpty }) {
                Button {
                    meta.select(.archives, archiveID: latest.id)
                } label: {
                    Label("\(latest.pack.data.count) guides archivés · \(latest.sourceName) · \(latest.pack.patch ?? "ancien patch")",
                          systemImage: "archivebox")
                        .font(.subheadline.bold())
                }.buttonStyle(.bordered)
            }
            if let message = meta.message, meta.selection.channel == .live {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
struct MetaCard: View {
    @EnvironmentObject private var store: Store
    let comp: MetaComp
    var body: some View {
        Panel {
            HStack(alignment: .top) {
                if comp.authored != nil {
                    Image(systemName: "hexagon").font(.title2).foregroundStyle(.mint).frame(width: 35, height: 40)
                } else {
                    Text(comp.tier).font(.title.bold()).foregroundStyle(hexaGold).frame(width: 35, height: 40)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(comp.title(store.reference)).font(.title3.bold()).foregroundStyle(.white)
                    Text(comp.style).font(.caption).foregroundStyle(hexaGold)
                }
                Spacer()
                Image(systemName: store.state.favorites.contains(comp.id) ? "star.fill" : "chevron.right").foregroundStyle(hexaGold)
            }
            UnitStrip(units: comp.units)
            if let stats = comp.stats {
                StatsStrip(stats: stats)
            } else {
                Label("Guide Hexa · plateaux et objets", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption).foregroundStyle(.mint)
            }
        }
    }
}
struct UnitStrip: View {
    @EnvironmentObject private var store: Store
    let units: [MetaUnit]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(units) { unit in
                    let entry = store.champion("champion:" + unit.name) ?? ReferenceEntry.boardEntity(unit.name)
                    Group {
                        VStack(spacing: 4) {
                            EntryIcon(entry: entry, size: 46)
                            Text(entry.name).font(.system(size: 10)).lineLimit(2).frame(width: 53)
                            if let stars = unit.star_level { Text(String(repeating: "★", count: min(3,max(1,Int(stars))))).font(.system(size: 8)).foregroundStyle(hexaGold) }
                        }.accessibilityLabel(entry.name)
                    }
                }
            }
        }
    }
}
struct StatsStrip: View {
    let stats: MetaStats
    var body: some View {
        HStack {
            metric("Place moy.", String(format: "%.2f",stats.avg_placement))
            Spacer(); metric("Top 4", String(format: "%.1f %%",stats.top_4_percent * 100))
            Spacer(); metric("Top 1", String(format: "%.1f %%",stats.top_1_percent * 100))
            Spacer(); metric("Parties", stats.nb_games.formatted())
        }
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(value).font(.subheadline.bold()).foregroundStyle(.white); Text(label).font(.system(size: 10)).foregroundStyle(.secondary) }
    }
}
struct MetaDetail: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var meta: MetaStore
    let comp: MetaComp
    @State private var stage = Stage.opening
    private var similar: [MetaComp] {
        let units = Set(comp.units.map(\.name))
        return meta.comps.filter { $0.id != comp.id }.map { candidate in
            let other = Set(candidate.units.map(\.name))
            let overlap = Double(units.intersection(other).count) / Double(max(1, units.union(other).count))
            return (candidate, overlap)
        }.filter { $0.1 >= 0.5 }.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    if comp.authored != nil { Badge(text: "GUIDE HEXA", color: .mint) }
                    else { Badge(text: "TIER \(comp.tier)", color: hexaGold) }
                    Badge(text: comp.style, color: hexaGold)
                    Spacer()
                }
                Text(comp.title(store.reference)).font(.title.bold())
                if let stats = comp.stats { StatsStrip(stats: stats) }
                HStack {
                    Button { store.pinMeta(comp) } label: { Label(store.state.pinnedID == comp.id ? "Épinglée" : "Suivre dans Partie", systemImage: "pin.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                    Button { store.favorite(comp.id) } label: { Image(systemName: store.state.favorites.contains(comp.id) ? "star.fill" : "star") }.buttonStyle(.bordered).accessibilityLabel("Ajouter ou retirer des favoris")
                }
                Text("Set \(meta.pack?.set ?? "—") · Patch \(meta.pack?.patch ?? "—") · \(comp.authored == nil ? meta.sourceName : "Plan éditorial Hexa")")
                    .font(.caption).foregroundStyle(.secondary)
                VisualCompositionGuide(comp: comp, stage: $stage)
                if let plan = comp.authored {
                    Panel {
                        Label("Quand jouer ce plan", systemImage: "map").font(.headline)
                        Text(plan.conditions)
                        Text("Placement").font(.headline)
                        Text(plan.positioning)
                        Text("Plan de secours").font(.headline)
                        Text(plan.pivot)
                    }.font(.subheadline)
                } else {
                    CompositionEvidence(comp: comp)
                }
                if comp.authored == nil, !similar.isEmpty {
                    Panel {
                        Label("Plans proches sur ce patch", systemImage: "arrow.triangle.branch").font(.headline)
                        Text("Au moins la moitié des champions sont communs sur l’ensemble des deux plateaux. Vérifie les porteurs avant de transférer tes objets.").font(.caption)
                        ForEach(similar) { option in
                            NavigationLink { MetaDetail(comp: option) } label: {
                                Text(option.title(store.reference) + " · " + option.style)
                            }
                        }
                    }
                }
                EquipmentRoster(comp: comp)
                Panel {
                    Label("Mon atelier", systemImage: "hexagon").font(.headline)
                    Button("Copier le plateau final dans mon atelier") { store.copyBoard(comp.units_positions ?? []) }.buttonStyle(.bordered)
                }
                if let augments = comp.augments, !augments.isEmpty {
                    Panel {
                        Text("Optimisations fréquentes").font(.headline)
                        ForEach(augments, id: \.self) { key in
                            if let augment = store.reference?.entries.first(where: { $0.id == "augment:" + key }) {
                                Text(augment.name).font(.subheadline.bold()); Text(augment.description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Panel {
                    Text("Source et contexte").font(.headline)
                    if let stats = comp.stats {
                        Text("\(meta.sourceName) · \(comp.region ?? "WORLD") · \(comp.rank ?? "PLATINUM+") · \(stats.nb_games.formatted()) parties").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Positions et parcours proposés par Hexa. Aucun taux de victoire ni échantillon associé.").font(.caption).foregroundStyle(.secondary)
                    }
                    if comp.stats != nil { Text("Version des statistiques déclarée par la source : \(comp.display_patch ?? "—"). Le patch de la page est indiqué dans Méta.").font(.caption).foregroundStyle(.secondary) }
                    if meta.sourceName == "Blitz" {
                        Link("Consulter la fiche originale Blitz", destination: comp.url)
                    } else if let url = comp.sourceURL, url.scheme == "https" {
                        Link("Consulter la source originale", destination: url)
                    }
                }
            }.padding()
        }.background(hexaNavy).navigationTitle("Composition").navigationBarTitleDisplayMode(.inline)
    }
}


struct CompositionEvidence: View {
    @EnvironmentObject private var store: Store
    let comp: MetaComp
    var body: some View {
        Panel {
            Label("Préparer ce plan", systemImage: "map").font(.headline)
            if let priorities = comp.carousel_priority, !priorities.isEmpty {
                Text("Composants prioritaires selon la source").font(.subheadline.bold())
                ItemIcons(keys: Array(priorities.prefix(3)))
            }
            if let conditions = comp.play_conditions, !conditions.isEmpty {
                Text("Conditions associées aux meilleurs résultats").font(.subheadline.bold())
                ForEach(Array(conditions.prefix(5).enumerated()), id: \.offset) { _, condition in
                    if let label = conditionLabel(condition) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label).font(.subheadline)
                            if let with = condition.avg_placement, let without = condition.avg_placement_without {
                                Text("Moyenne avec \(with, format: .number.precision(.fractionLength(2))) · sans \(without, format: .number.precision(.fractionLength(2)))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Text("Association statistique sur l’échantillon du fournisseur. Une unité améliorée peut aussi refléter une partie déjà favorable.").font(.caption2).foregroundStyle(.secondary)
            }
            if let traits = comp.traits, !traits.isEmpty {
                let names = traits.prefix(8).compactMap { trait in
                    store.reference?.entries.first { $0.id == "trait:" + trait.trait_api_name }?.name
                }
                if !names.isEmpty {
                    Text("Traits fréquemment observés").font(.subheadline.bold())
                    Text(names.joined(separator: " · ")).font(.caption)
                }
            }
            Text("Positionnement").font(.subheadline.bold())
            Text("Place les unités défensives face aux premières menaces. Sépare les porteurs lorsque les dégâts de zone punissent un regroupement. Utilise le plateau final du guide pour repérer les unités à protéger.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func conditionLabel(_ condition: MetaCondition) -> String? {
        let kind = condition.type == "unit" ? "champion" : condition.type
        guard let entry = store.reference?.entries.first(where: { $0.id == kind + ":" + condition.name }) else { return nil }
        if let stars = condition.unit_star_level { return entry.name + " · " + String(stars) + " ★" }
        if let count = condition.trait_min_count { return entry.name + " · palier " + String(count) }
        return entry.name
    }
}
