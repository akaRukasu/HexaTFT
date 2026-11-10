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
    @State private var sort: MetaSort = .top4
    @State private var gems = false
    @State private var showingObservations = true
    @State private var provider: MetaObservation.Provider?
    private var styles: [String] { ["Tous"] + Set((meta.comps + meta.editorialComps).map(\.style)).sorted() }
    private var filtered: [MetaComp] {
        let comps = (meta.comps + meta.editorialComps).filter { comp in
            (!favorites || store.state.favorites.contains(comp.id)) &&
            (style == "Tous" || comp.style == style) &&
            (!gems || comp.stats.map { $0.nb_games >= 500 && $0.pick_rate <= 0.03 && $0.avg_placement < 4.5 } == true) &&
            (query.isEmpty || searchable(comp).localizedStandardContains(query))
        }
        if meta.selection.channel == .pbe, meta.comps.isEmpty { return comps }
        let related = meta.selection.channel == .live && meta.radar.matches(meta.reference) ?
            Dictionary(meta.radar.readings.compactMap { reading in reading.relatedGuide.map { ($0, reading) } },
                       uniquingKeysWith: { first, _ in first }) : [:]
        return sort.guides(comps) { comp in
            if let stats = comp.stats {
                return sort.score(average: stats.avg_placement, top4: stats.top_4_percent, top1: stats.top_1_percent)
            }
            guard let reading = related[comp.comp_id] else { return -.infinity }
            return sort.score(average: reading.average, top4: reading.top4, top1: reading.top1)
        }
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
                if meta.selection.channel == .live {
                    Picker("Catalogue", selection: $showingObservations) {
                        Text("Stats et compos").tag(true)
                        Text("Guides").tag(false)
                    }.pickerStyle(.segmented).accessibilityIdentifier("meta-library")
                    if showingObservations {
                        observations
                    } else {
                        guideShelf
                    }
                } else {
                    guideShelf
                    if meta.selection.channel == .pbe {
                        NavigationLink("Archives et sources PBE") { ScrollView { PBEGuideList().padding() }.navigationTitle("Sources PBE") }
                    }
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
    private var observations: some View {
        let snapshot = meta.radar
        let compatible = snapshot.matches(store.reference)
        let readings = sort.readings(snapshot.readings.filter {
            $0.matches(query) && (provider == nil || $0.provider == provider)
        })
        let includesArchives = provider == nil
        return Group {
            HStack {
                Label("Compositions et statistiques", systemImage: "chart.bar.xaxis").font(.headline)
                Spacer()
            }
            HStack {
                Picker("Source", selection: $provider) {
                    Text("Toutes les sources").tag(nil as MetaObservation.Provider?)
                    ForEach(MetaObservation.Provider.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }.labelsHidden().accessibilityIdentifier("meta-observation-source")
                Spacer()
                Picker("Trier", selection: $sort) {
                    ForEach(MetaSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.labelsHidden().accessibilityIdentifier("meta-observation-sort")
            }
            Text(snapshot.label + " · " + readings.count.formatted() + " relevés")
                .font(.caption).foregroundStyle(.secondary)
            if !compatible {
                Text("Relevé d’un patch antérieur").font(.caption.bold()).foregroundStyle(.orange)
            }
            Text("Les rangs et les échantillons varient selon la source.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(readings) { entry in
                observationRow(entry, reference: compatible ? store.reference : nil)
            }
            if snapshot.nextCursor != nil {
                if let error = meta.radarPageError {
                    Button("Réessayer la page suivante") { Task { await meta.loadNextRadarPage() } }.buttonStyle(.bordered)
                    Text(error).font(.caption).foregroundStyle(.secondary)
                } else {
                    ProgressView("Chargement de nouvelles compositions")
                        .frame(maxWidth: .infinity).padding()
                        .task(id: snapshot.nextCursor) { await meta.loadNextRadarPage() }
                }
            }
            if provider == nil, !meta.comps.isEmpty {
                Text("Guides chiffrés · " + meta.sourceName).font(.title3.bold())
                ForEach(filtered.filter { $0.stats != nil }) { comp in
                    NavigationLink { MetaDetail(comp: comp) } label: { MetaCard(comp: comp) }.buttonStyle(.plain)
                }
            }
            if includesArchives {
                ForEach(meta.archives) { archive in
                    let matching = archivedComps(archive)
                    if !matching.isEmpty {
                        Section {
                            ForEach(matching) { comp in archiveRow(comp, snapshot: archive) }
                        } header: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Patch " + (archive.pack.patch ?? "archivé"), systemImage: "archivebox")
                                    .font(.title3.bold())
                                Text(archive.sourceName + " · Archives · " + matching.count.formatted() + " fiches")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else if readings.isEmpty, snapshot.nextCursor == nil {
                ContentUnavailableView("Aucun relevé pour ce filtre", systemImage: "magnifyingglass")
            }
        }
    }

    private func observationRow(_ entry: MetaObservation, reference: ReferenceData?) -> some View {
        NavigationLink {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    MetaObservationCard(entry: entry, reference: reference)
                    Link("Ouvrir le relevé d’origine", destination: entry.source).buttonStyle(.bordered)
                    if reference != nil, let guide = meta.editorialComps.first(where: { entry.relatedGuide == $0.comp_id }) {
                        NavigationLink("Ouvrir le guide Hexa associé") { MetaDetail(comp: guide) }.buttonStyle(.borderedProminent)
                        Text("Les chiffres décrivent le regroupement du fournisseur. Le plateau Hexa est une proposition de jeu pour cet archétype.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding()
            }.background(hexaNavy).navigationTitle("Composition")
        } label: {
            MetaObservationCard(entry: entry, reference: reference)
        }.buttonStyle(.plain).accessibilityIdentifier("observation-" + entry.id)
    }

    private func archivedComps(_ snapshot: PatchSnapshot) -> [MetaComp] {
        sort.guides(snapshot.pack.data.filter {
            query.isEmpty || ($0.title(snapshot.reference) + " " + $0.style + " " + snapshot.sourceName).localizedStandardContains(query)
        }) { comp in
            guard let stats = comp.stats else { return -.infinity }
            return sort.score(average: stats.avg_placement, top4: stats.top_4_percent, top1: stats.top_1_percent)
        }
    }

    private func archiveRow(_ comp: MetaComp, snapshot: PatchSnapshot) -> some View {
        NavigationLink {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    archiveCard(comp, snapshot: snapshot)
                    Button("Voir le catalogue de ce patch") { meta.select(.archives, archiveID: snapshot.id) }
                        .buttonStyle(.borderedProminent)
                    if let url = comp.sourceURL ?? (snapshot.sourceName == "Blitz" ? comp.url : nil) {
                        Link("Voir la fiche d’origine", destination: url)
                            .buttonStyle(.bordered)
                    }
                }.padding()
            }.background(hexaNavy).navigationTitle("Composition archivée")
        } label: {
            archiveCard(comp, snapshot: snapshot)
        }.buttonStyle(.plain).accessibilityIdentifier("home-archive-" + snapshot.id + "-" + comp.id)
    }

    private func archiveCard(_ comp: MetaComp, snapshot: PatchSnapshot) -> some View {
        Panel {
            HStack {
                Text(comp.title(snapshot.reference)).font(.headline)
                Spacer()
                Badge(text: "TIER " + comp.tier, color: hexaGold)
            }
            Text(snapshot.sourceName + " · Patch " + (snapshot.pack.patch ?? "archivé"))
                .font(.caption).foregroundStyle(.secondary)
            if let reference = snapshot.reference {
                UnitStrip(units: comp.units, reference: reference)
            }
            if let stats = comp.stats { StatsStrip(stats: stats) }
        }
    }

    @ViewBuilder private var archiveShortcut: some View {
        if query.isEmpty, let latest = meta.archives.first(where: { !$0.pack.data.isEmpty }) {
            Button {
                meta.select(.archives, archiveID: latest.id)
            } label: {
                Label("\(latest.pack.data.count) guides avec stats · Patch \(latest.pack.patch ?? "archivé")",
                      systemImage: "archivebox").font(.subheadline.bold())
            }.buttonStyle(.bordered)
        }
    }

    private var guideShelf: some View {
        Group {
            Text(meta.selection.channel == .archives ? "Guides archivés" : meta.selection.channel == .pbe ? "Compositions PBE" : "Guides du patch").font(.title2.bold())
            if meta.selection.channel == .archives {
                Text(meta.sourceName + " · " + String((meta.pack?.retrievedAt ?? "").prefix(10)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if meta.selection.channel == .pbe {
                Text(meta.comps.isEmpty ? "Plateaux à tester sur cette révision. Les cartes indiquent les paliers et la taille du noyau." :
                    "Relevés de " + meta.sourceName + " et noyaux théoriques Hexa pour cette révision.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !meta.comps.isEmpty || !meta.editorialComps.isEmpty {
                HStack {
                    if styles.count > 1 {
                        Picker("Style", selection: $style) { ForEach(styles, id: \.self) { Text($0).tag($0) } }
                    }
                    if !meta.comps.isEmpty || meta.selection.channel == .live {
                        Picker("Trier", selection: $sort) {
                            ForEach([MetaSort.top4, .top1, .average], id: \.self) { Text($0.rawValue).tag($0) }
                            if sort == .discovery { Text(MetaSort.discovery.rawValue).tag(MetaSort.discovery) }
                        }
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
            if meta.selection.channel == .live, !favorites, !gems { archiveShortcut }
            if let message = meta.message, meta.selection.channel == .live {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
struct MetaCard: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var meta: MetaStore
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
            } else if meta.selection.channel == .pbe {
                HStack {
                    DashboardMetric(title: "Unités", value: comp.units.count.formatted(), accent: .mint)
                    if let tiers = comp.authored?.traitThresholds, !tiers.isEmpty {
                        DashboardMetric(title: "Paliers du trait", value: tiers.map(String.init).joined(separator: " / "))
                    }
                }
            } else if meta.selection.channel == .live, meta.radar.matches(store.reference),
                      let reading = meta.radar.readings.first(where: { $0.relatedGuide == comp.comp_id }) {
                MetaObservationMetrics(entry: reading)
                Text("Archétype observé · " + reading.provider.rawValue).font(.caption2).foregroundStyle(.secondary)
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
    var reference: ReferenceData? = nil
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(units) { unit in
                    let entry = (reference ?? store.reference)?.entries.first { $0.id == "champion:" + unit.name } ?? ReferenceEntry.boardEntity(unit.name)
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
                Text(meta.selection.channel == .pbe ? "PBE · " + (meta.experimental?.version ?? "—") + " · " + (comp.stats == nil ? "Plateau à tester" : meta.sourceName) :
                     "Set \(meta.pack?.set ?? "—") · Patch \(meta.pack?.patch ?? "—") · \(comp.authored == nil ? meta.sourceName : "Plan éditorial Hexa")")
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
