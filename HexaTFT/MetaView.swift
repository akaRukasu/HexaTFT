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
    private var styles: [String] { ["Tous"] + Set(meta.comps.map(\.style)).sorted() }
    private var filtered: [MetaComp] {
        let comps = meta.comps.filter { comp in
            (!favorites || store.state.favorites.contains(comp.id)) && (style == "Tous" || comp.style == style) &&
            (query.isEmpty || (comp.title(store.reference) + " " + comp.units.map { name($0.name) }.joined(separator: " ")).localizedCaseInsensitiveContains(query))
        }
        return sort == "Top 4" ? comps.sorted { $0.stats.top_4_percent > $1.stats.top_4_percent } : comps
    }
    private func name(_ key: String) -> String { store.champion("champion:" + key)?.name ?? key }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HexaBrand()
                HStack {
                    Badge(text: "SET \(meta.pack?.set ?? "—")", color: hexaGold)
                    Badge(text: "PATCH \(meta.pack?.patch ?? "—")", color: hexaGold)
                    Spacer()
                    Text("\(meta.comps.count) compos").font(.caption).foregroundStyle(.secondary)
                }
                Text("La méta, à portée de main.").font(.title.bold())
                NavigationLink { SourcesView() } label: {
                    HStack { Image(systemName: "globe"); Text("Mobalytics · MetaTFT · Blitz").font(.subheadline.bold()); Spacer(); Image(systemName: "arrow.up.right") }
                        .padding().background(hexaGold.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).foregroundStyle(hexaGold)
                Text("Fiches natives : Blitz · \(String((meta.pack?.retrievedAt ?? "").prefix(10))) · Monde · Platine+")
                    .font(.caption).foregroundStyle(.secondary)
                if let message = meta.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Picker("Style", selection: $style) { ForEach(styles, id: \.self) { Text($0).tag($0) } }
                    Picker("Trier", selection: $sort) { Text("Moyenne").tag("Moyenne"); Text("Top 4").tag("Top 4") }
                    Spacer()
                    Button { favorites.toggle() } label: { Image(systemName: favorites ? "star.fill" : "star") }
                        .accessibilityLabel(favorites ? "Afficher toutes les compos" : "Afficher les favoris")
                }.tint(hexaGold)
                ForEach(filtered) { comp in
                    NavigationLink { MetaDetail(comp: comp) } label: { MetaCard(comp: comp) }.buttonStyle(.plain).accessibilityIdentifier("meta-card-" + comp.comp_id)
                }
                if filtered.isEmpty { ContentUnavailableView("Aucune composition", systemImage: "magnifyingglass", description: Text("Change la recherche ou les filtres.")) }
                Text("Statistiques observées, sans garantie de résultat. Les variantes sont des plateaux relevés dans les données de la source.").font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
        .background(hexaNavy).navigationTitle("Méta").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Champion, composition…")
        .refreshable { await meta.refresh(reference: store.reference) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { NavigationLink { JournalView() } label: { Image(systemName: "person.crop.circle") }.accessibilityLabel("Profil et journal") }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await meta.refresh(reference: store.reference) } } label: {
                    if meta.refreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                }.disabled(meta.refreshing).accessibilityLabel("Actualiser les compositions")
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
                Text(comp.tier).font(.title.bold()).foregroundStyle(hexaGold).frame(width: 35, height: 40)
                VStack(alignment: .leading, spacing: 6) {
                    Text(comp.title(store.reference)).font(.title3.bold()).foregroundStyle(.white)
                    Text(comp.style).font(.caption).foregroundStyle(hexaGold)
                }
                Spacer()
                Image(systemName: store.state.favorites.contains(comp.id) ? "star.fill" : "chevron.right").foregroundStyle(hexaGold)
            }
            UnitStrip(units: comp.units)
            StatsStrip(comp: comp)
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
                    if let entry = store.champion("champion:" + unit.name) {
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
    let comp: MetaComp
    var body: some View {
        HStack {
            metric("Place moy.", String(format: "%.2f",comp.stats.avg_placement))
            Spacer(); metric("Top 4", String(format: "%.1f %%",comp.stats.top_4_percent * 100))
            Spacer(); metric("Top 1", String(format: "%.1f %%",comp.stats.top_1_percent * 100))
            Spacer(); metric("Parties", comp.stats.nb_games.formatted())
        }
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(value).font(.subheadline.bold()).foregroundStyle(.white); Text(label).font(.system(size: 10)).foregroundStyle(.secondary) }
    }
}
struct MetaBoard: View {
    @EnvironmentObject private var store: Store
    let positions: [MetaPosition]
    var body: some View {
        VStack(spacing: 6) {
            Text("VERS L’ADVERSAIRE").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.secondary)
            GeometryReader { geometry in
                let width = (geometry.size.width - 24) / 7.5
                VStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { col in
                                let position = positions.first { $0.board_position == row * 7 + col }
                                let entry = position.flatMap { store.champion("champion:" + $0.unit_api_name) }
                                ZStack {
                                    Hexagon().fill(hexaGold.opacity(entry == nil ? 0.035 : 0.16))
                                    if let entry { EntryIcon(entry: entry, size: width).clipShape(Hexagon()) }
                                    Hexagon().strokeBorderCompat(hexaGold.opacity(entry == nil ? 0.13 : 0.65))
                                }.frame(width: width, height: width * 1.1)
                                    .accessibilityLabel("Ligne \(row+1), case \(col+1) : \(entry?.name ?? "vide")")
                            }
                        }.offset(x: row.isMultiple(of: 2) ? 0 : width / 2)
                    }
                }
            }.aspectRatio(1.6, contentMode: .fit)
        }
    }
}
extension Hexagon {
    func strokeBorderCompat(_ color: Color) -> some View { stroke(color, lineWidth: 1) }
}
struct MetaDetail: View {
    @EnvironmentObject private var store: Store
    let comp: MetaComp
    @State private var stage = Stage.opening
    @State private var level = "8"
    @State private var variantIndex = 0
    private func entry(_ key: String, kind: String = "champion") -> ReferenceEntry? { store.reference?.entries.first { $0.id == kind + ":" + key } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Badge(text: "TIER \(comp.tier)", color: hexaGold); Badge(text: comp.style, color: hexaGold); Spacer() }
                Text(comp.title(store.reference)).font(.largeTitle.bold())
                StatsStrip(comp: comp)
                HStack {
                    Button { store.pinMeta(comp) } label: { Label(store.state.pinnedID == comp.id ? "Épinglée" : "Suivre dans Partie", systemImage: "pin.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                    Button { store.favorite(comp.id) } label: { Image(systemName: store.state.favorites.contains(comp.id) ? "star.fill" : "star") }.buttonStyle(.bordered).accessibilityLabel("Ajouter ou retirer des favoris")
                }
                Panel {
                    Text("Plateau principal").font(.headline)
                    MetaBoard(positions: comp.units_positions ?? [])
                    UnitStrip(units: comp.units)
                    Text("Placement de référence de Blitz. Consulte les variantes selon le niveau et le stade.").font(.caption).foregroundStyle(.secondary)
                    Button("Copier dans mon atelier") { store.copyBoard(comp.units_positions ?? []) }.buttonStyle(.bordered)
                }
                Panel {
                    Text("Objets et porteurs").font(.headline)
                    ForEach(comp.units.filter { !($0.items ?? []).isEmpty }) { unit in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry(unit.name)?.name ?? unit.name).font(.subheadline.bold())
                            ItemLine(keys: unit.items ?? [])
                            if let alternatives = comp.units_stats?.first(where: { $0.name == unit.name })?.item_trios {
                                ForEach(Array(alternatives.prefix(3).enumerated()), id: \.offset) { index, trio in
                                    Text(index == 0 ? "Trio fréquent" : "Alternative \(index)").font(.caption).foregroundStyle(.secondary)
                                    ItemLine(keys: trio.item_api_names)
                                }
                            }
                        }.padding(.vertical, 6)
                    }
                }
                Panel {
                    Text("Progression par stade").font(.headline)
                    StageSelector(stage: $stage)
                    MetaStage(comp: comp, stage: stage)
                }
                Panel {
                    Text("Variantes par niveau").font(.headline)
                    let levels = (comp.variations?.levels?.keys.map { $0 } ?? []).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
                    if levels.isEmpty { Text("Aucun plateau par niveau fourni par cette source.").font(.caption) }
                    else {
                        Picker("Niveau", selection: $level) { ForEach(levels, id: \.self) { Text("Niv. " + $0).tag($0) } }.pickerStyle(.menu)
                        ForEach(Array((comp.variations?.levels?[level] ?? []).prefix(3).enumerated()), id: \.offset) { index, variant in
                            VariantPanel(variant: variant, title: "Option \(index + 1)")
                        }
                    }
                }
                if let holders = comp.carry_item_holders, !holders.isEmpty {
                    Panel {
                        Text("Porteurs temporaires observés").font(.headline)
                        ForEach(Array(holders.enumerated()), id: \.offset) { _, holder in
                            Text("Vers \(entry(holder.end_game_carry_api_name)?.name ?? holder.end_game_carry_api_name)").font(.subheadline.bold())
                            Text(holder.stats.prefix(3).map { entry($0.early_game_carry_api_name)?.name ?? $0.early_game_carry_api_name }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                if let augments = comp.augments, !augments.isEmpty {
                    Panel {
                        Text("Optimisations fréquentes").font(.headline)
                        ForEach(augments, id: \.self) { key in
                            if let augment = entry(key, kind: "augment") { Text(augment.name).font(.subheadline.bold()); Text(augment.description).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                Panel {
                    Text("Source et contexte").font(.headline)
                    Text("Blitz · \(comp.region ?? "WORLD") · \(comp.rank ?? "PLATINUM+")\n\(comp.stats.nb_games.formatted()) parties · Fréquence \(String(format: "%.1f %%",comp.stats.pick_rate * 100))").font(.caption).foregroundStyle(.secondary)
                    Text("Identifiant de patch dans l’API Blitz : \(comp.display_patch ?? "—"). Le patch affiché sur la page est indiqué dans Méta.").font(.caption).foregroundStyle(.secondary)
                    NavigationLink("Consulter la fiche complète Blitz") { EmbeddedPage(url: comp.url).navigationTitle("Blitz").navigationBarTitleDisplayMode(.inline) }
                }
            }.padding()
        }.background(hexaNavy).navigationTitle("Composition").navigationBarTitleDisplayMode(.inline)
        .onAppear { if comp.variations?.levels?[level] == nil { level = comp.variations?.levels?.keys.sorted().first ?? "8" } }
    }
}
struct ItemLine: View {
    @EnvironmentObject private var store: Store
    let keys: [String]
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                if let item = store.reference?.entries.first(where: { $0.id == "item:" + key }) {
                    NavigationLink {
                        ScrollView { VStack(alignment: .leading, spacing: 16) { EntryIcon(entry: item, size: 70); Text(item.name).font(.title.bold()); Text(item.description) }.padding() }.navigationTitle("Équipement")
                    } label: {
                        VStack(spacing: 4) { EntryIcon(entry: item, size: 32); Text(item.name).font(.system(size: 10)).multilineTextAlignment(.center) }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
struct StageSelector: View {
    @Binding var stage: Stage
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack { ForEach(Stage.allCases) { value in Button(value.rawValue) { stage = value }.buttonStyle(.bordered).tint(stage == value ? hexaGold : .gray).accessibilityAddTraits(stage == value ? .isSelected : []) } }
        }
    }
}
struct MetaStage: View {
    let comp: MetaComp
    let stage: Stage
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stage.title).font(.title3.bold())
            Text(comp.style).font(.subheadline).foregroundStyle(hexaGold)
            if let levels = comp.strategy?.level_stage {
                let matching = levels.keys.filter { levels[$0]?.replacingOccurrences(of: ".", with: "-") == stage.rawValue }.sorted()
                ForEach(matching, id: \.self) { Text("Repère observé : niveau \($0) au stade \(stage.rawValue).").font(.subheadline) }
            }
            let variants = comp.variants(for: stage)
            if variants.isEmpty {
                Text("La source ne fournit pas de plateau précis pour ce stade. Le plateau principal et les variantes par niveau restent disponibles dans la fiche.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(variants.enumerated()), id: \.offset) { index, variant in VariantPanel(variant: variant, title: "Plateau observé \(index + 1)") }
            }
            Text("Repères d’économie généraux : garde tes paliers d’intérêts quand ton plateau le permet ; stabilise avant de dépenser pour le niveau suivant. Adapte les dépenses à tes PV et aux unités disponibles.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct VariantPanel: View {
    let variant: MetaVariant
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider(); Text(title).font(.subheadline.bold())
            if let positions = variant.units_positions, !positions.isEmpty { MetaBoard(positions: positions) }
            UnitStrip(units: variant.units)
            if let count = variant.nb_boards { Text("\(count.formatted()) plateaux observés").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
