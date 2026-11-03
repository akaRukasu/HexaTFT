import SwiftUI

struct BoardView: View {
    @EnvironmentObject private var store: Store
    @State private var selected: BoardCell?
    @State private var confirmingClear = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Badge(text: "ATELIER PERSONNEL")
                Text("Dessine ton plateau.").font(.largeTitle.bold())
                Text("Touche une case pour ajouter ou remplacer un champion. Le plateau reste indépendant du guide consulté.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Panel {
                    Text("VERS L’ADVERSAIRE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    GeometryReader { geometry in
                        let width = (geometry.size.width - 20) / 7.5
                        VStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { row in
                                HStack(spacing: 3) {
                                    ForEach(0..<7, id: \.self) { col in
                                        let index = row * 7 + col
                                        let entry = store.champion(store.state.board[index] ?? "")
                                        Button { selected = BoardCell(id: index) } label: {
                                            ZStack {
                                                Hexagon().fill(entry == nil ? Color.white.opacity(0.045) : Color.mint.opacity(0.18))
                                                Hexagon().stroke(.mint.opacity(entry == nil ? 0.18 : 0.65), lineWidth: 1)
                                                if let entry {
                                                    EntryIcon(entry: entry, size: width).clipShape(Hexagon())
                                                } else { Image(systemName: "plus").font(.caption2).foregroundStyle(.secondary) }
                                            }.frame(width: width, height: width * 1.1).contentShape(Hexagon())
                                        }.buttonStyle(.plain)
                                            .accessibilityLabel("Ligne \(row + 1), case \(col + 1), \(entry?.name ?? "vide")")
                                    }
                                }.offset(x: row.isMultiple(of: 2) ? 0 : width / 2)
                            }
                        }
                    }.aspectRatio(1.55, contentMode: .fit)
                    Text("\(store.state.board.count) unités placées · 4 × 7 cases").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(store.state.board.keys.sorted(), id: \.self) { index in
                    if let entry = store.champion(store.state.board[index] ?? "") {
                        HStack {
                            EntryIcon(entry: entry)
                            VStack(alignment: .leading) {
                                Text(entry.name).font(.headline)
                                Text("Set \(entry.set) · Ligne \(index / 7 + 1), case \(index % 7 + 1)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { store.place(nil, at: index) } label: { Image(systemName: "minus.circle") }
                                .accessibilityLabel("Retirer \(entry.name)")
                        }
                    }
                }
                HStack {
                    ShareLink(item: store.boardText) { Label("Partager", systemImage: "square.and.arrow.up") }
                    Spacer()
                    Button("Vider", role: .destructive) { confirmingClear = true }.disabled(store.state.board.isEmpty)
                }.buttonStyle(.bordered)
                Text("Les champions et les objets du set de la source sont disponibles hors connexion.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }.navigationTitle("Plateau")
        .sheet(item: $selected) { cell in
            NavigationStack {
                ChampionPicker { entry in store.place(entry, at: cell.id); selected = nil }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { selected = nil } } }
            }
        }
        .confirmationDialog("Vider ton plateau ?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Vider le plateau", role: .destructive) { store.clearBoard() }
        }
    }
}

private struct BoardCell: Identifiable { let id: Int }

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<6 {
            let angle = Double(index) * .pi / 3 - .pi / 2
            let point = CGPoint(x: rect.midX + CGFloat(cos(angle)) * rect.width / 2,
                                y: rect.midY + CGFloat(sin(angle)) * rect.height / 2)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath(); return path
    }
}

struct ChampionPicker: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var selectedSet = "Tous"
    let choose: (ReferenceEntry) -> Void
    private var sets: [String] { ["Tous"] + Set(store.champions.map(\.set)).sorted() }
    var body: some View {
        List {
            Picker("Set", selection: $selectedSet) { ForEach(sets, id: \.self) { Text($0).tag($0) } }
            ForEach(store.champions.filter {
                (selectedSet == "Tous" || $0.set == selectedSet) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
            }.sorted { ($0.cost, $0.name, $0.id) < ($1.cost, $1.name, $1.id) }) { entry in
                Button { choose(entry) } label: {
                    HStack {
                        EntryIcon(entry: entry)
                        VStack(alignment: .leading) { Text(entry.name); Text("Set \(entry.set)").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Text("\(entry.cost) PO").font(.caption).foregroundStyle(.yellow)
                    }
                }.tint(.primary)
            }
        }.searchable(text: $query, prompt: "Nom du champion").navigationTitle("Choisir une unité")
    }
}

struct CodexView: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var kind = "champion"
    @State private var selectedSet = "Tous"
    private var entries: [ReferenceEntry] { store.reference?.entries ?? [] }
    private var sets: [String] { ["Tous"] + Set(entries.map(\.set)).sorted() }
    var body: some View {
        List {
            Section {
                Text("Données françaises Blitz \(store.reference?.version ?? "—") · Français")
                    .font(.subheadline)
                Text("Snapshot du \(store.reference.map { String($0.retrievedAt.prefix(10)) } ?? "—"). Ce Codex est limité au set des fiches natives.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Catégorie", selection: $kind) {
                    Text("Champions").tag("champion"); Text("Objets").tag("item")
                    Text("Traits").tag("trait"); Text("Optimisations").tag("augment")
                }
                Picker("Set", selection: $selectedSet) { ForEach(sets, id: \.self) { Text($0).tag($0) } }
            }
            ForEach(entries.filter {
                $0.kind == kind && (selectedSet == "Tous" || $0.set == selectedSet) &&
                (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
            }.sorted { ($0.name, $0.id) < ($1.name, $1.id) }) { entry in
                NavigationLink {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            EntryIcon(entry: entry, size: 80)
                            Text(entry.name).font(.largeTitle.bold())
                            Badge(text: "Set \(entry.set)")
                            if entry.kind == "champion" { Text("Coût : \(entry.cost) PO") }
                            Text(entry.description.isEmpty ? "Cette source ne fournit pas de description détaillée pour cet élément." : entry.description)
                            Text("Les variables entre @…@ ou accolades sont des paramètres bruts de la source ; leurs valeurs ne sont pas calculées ici.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding()
                    }.navigationTitle("Codex").navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack {
                        EntryIcon(entry: entry)
                        VStack(alignment: .leading) { Text(entry.name); Text("Set \(entry.set)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }.navigationTitle("Codex").navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "Chercher dans le Codex")
    }
}

struct JournalView: View {
    @EnvironmentObject private var store: Store
    @State private var adding = false
    var body: some View {
        List {
            Section("Ton carnet de progression") {
                HStack {
                    VStack(alignment: .leading) { Text("\(store.state.matches.count)").font(.largeTitle.bold()); Text("parties notées").font(.caption) }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(store.top4Rate.map { "\(Int(($0 * 100).rounded())) %" } ?? "—").font(.largeTitle.bold()).foregroundStyle(.mint)
                        Text("top 4 · notes locales").font(.caption)
                    }
                }
                Text("Journal saisi manuellement. Aucune connexion au compte Riot dans cette version.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Après la partie") {
                if store.state.matches.isEmpty { Text("Note ton premier résultat et ce que tu veux améliorer.").foregroundStyle(.secondary) }
                ForEach(store.state.matches) { match in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Badge(text: "TOP \(match.placement)", color: match.placement <= 4 ? .mint : .orange); Text(match.guideName).font(.headline) }
                        Text(match.date, style: .date).font(.caption).foregroundStyle(.secondary)
                        Text("Catalogue : \(match.patch)").font(.caption).foregroundStyle(.secondary)
                        if !match.notes.isEmpty { Text(match.notes).font(.subheadline) }
                    }.padding(.vertical, 5)
                }.onDelete(perform: store.deleteMatches)
            }
            Section("À propos") {
                Text("Hexa \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") · Compagnon TFT").font(.subheadline)
                Text("Projet indépendant, non affilié à Riot Games. Teamfight Tactics et ses éléments sont des marques et contenus de Riot Games.").font(.caption).foregroundStyle(.secondary)
                Link("Règles développeurs TFT", destination: URL(string: "https://developer.riotgames.com/docs/tft")!)
            }
        }.navigationTitle("Progression")
        .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Noter une partie") }
        .sheet(isPresented: $adding) { AddMatchView() }
    }
}

struct AddMatchView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var placement = 4
    @State private var notes = ""
    var body: some View {
        NavigationStack {
            Form {
                Picker("Placement", selection: $placement) { ForEach(1...8, id: \.self) { Text("Top \($0)").tag($0) } }
                Section("Ce que je retiens") { TextEditor(text: $notes).frame(minHeight: 150) }
                Text("Plan : \(store.pinned?.name ?? store.state.pinnedName ?? "Plan libre")").font(.caption)
            }.navigationTitle("Bilan de partie")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Enregistrer") { store.addMatch(placement: placement, notes: notes); if store.error == nil { dismiss() } }
                            .disabled(notes.count > 4_000)
                    }
                }
        }
    }
}
