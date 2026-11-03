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
struct MetaDetail: View {
    @EnvironmentObject private var store: Store
    let comp: MetaComp
    @State private var stage = Stage.opening
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Badge(text: "TIER \(comp.tier)", color: hexaGold); Badge(text: comp.style, color: hexaGold); Spacer() }
                Text(comp.title(store.reference)).font(.title.bold())
                StatsStrip(comp: comp)
                HStack {
                    Button { store.pinMeta(comp) } label: { Label(store.state.pinnedID == comp.id ? "Épinglée" : "Suivre dans Partie", systemImage: "pin.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                    Button { store.favorite(comp.id) } label: { Image(systemName: store.state.favorites.contains(comp.id) ? "star.fill" : "star") }.buttonStyle(.bordered).accessibilityLabel("Ajouter ou retirer des favoris")
                }
                VisualCompositionGuide(comp: comp, stage: $stage)
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
                    Text("Blitz · \(comp.region ?? "WORLD") · \(comp.rank ?? "PLATINUM+") · \(comp.stats.nb_games.formatted()) parties").font(.caption).foregroundStyle(.secondary)
                    Text("Version des statistiques déclarée par Blitz : \(comp.display_patch ?? "—"). Le patch de la page est indiqué dans Méta.").font(.caption).foregroundStyle(.secondary)
                    NavigationLink("Consulter la fiche complète Blitz") { EmbeddedPage(url: comp.url).navigationTitle("Blitz").navigationBarTitleDisplayMode(.inline) }
                }
            }.padding()
        }.background(hexaNavy).navigationTitle("Composition").navigationBarTitleDisplayMode(.inline)
    }
}
