import SwiftUI
import UniformTypeIdentifiers

struct PatchPicker: View {
    @EnvironmentObject private var meta: MetaStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Contexte TFT", selection: Binding(get: { meta.selection.channel }, set: { meta.select($0) })) {
                ForEach(PatchSelection.Channel.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("patch-context")
            if meta.selection.channel == .archives, let archive = meta.archive {
                Picker("Patch archivé", selection: Binding(get: { archive.id }, set: { meta.select(.archives, archiveID: $0) })) {
                    ForEach(meta.archives) { snapshot in
                        Text("Set \(snapshot.pack.set ?? "—") · \(snapshot.pack.patch ?? "—")").tag(snapshot.id)
                    }
                }
            } else if meta.selection.channel == .pbe {
                Label("Expérimental · \(meta.experimental?.version ?? "version inconnue")", systemImage: "flask")
                    .font(.caption).foregroundStyle(hexaGold)
            }
        }
    }
}

struct PatchNote: Identifiable {
    let patch: String
    let published: String
    let summary: String
    let groups: [ChangeGroup]
    var id: String { patch }
    var url: URL { URL(string: "https://teamfighttactics.leagueoflegends.com/en-us/news/game-updates/teamfight-tactics-patch-" + patch.replacingOccurrences(of: ".", with: "-") + "/")! }
    struct ChangeGroup: Identifiable {
        let name: String
        let lines: [String]
        var id: String { name }
    }
    static let notes: [Self] = [
        .init(patch: "18.6", published: "3 novembre 2026", summary: "Arrivée du client TFT autonome et ajustements d’équilibrage du set 18. Riot a ajouté des corrections à ses notes les 6 et 10 novembre.", groups: [
            .init(name: "Traits", lines: ["Floraison · AD/AP 12/30/50/55 % → 12/30/55/65 %", "Sylvestre (9) · bonus de PV 25 % → 10 %", "Sprykin · bonus AD/AP du partenaire à distance 15/28/33 % → 15/30/38 %"]),
            .init(name: "Champions", lines: ["Kobuko · soin 285/335/480 → 300/350/550", "Rek’Sai · soin 10/14/20 → 10/16/24", "Malphite · bouclier 735/885/2 000 → 750/925/2 000", "Nidalee AD · bonus du troisième sort 125 % → 140 %", "Sentinelle · ratio de PV du bouclier 10 % → 12 %"]),
            .init(name: "Optimisations", lines: ["Clockwork Accelerator · vitesse d’attaque par activation 10 % → 12 %", "Embiggen · AD/AP de Pixie 50 % → 35 %", "Plot Armor · résistances 8 → 10", "Shopping Spree · or initial 6 → 7"]),
            .init(name: "Économie et feux follets", lines: ["Curio Cart · coût d’un emblème 15 → 17 PO", "Middle Path · coût initial 4 → 5 PO, amélioration 3 → 4 PO"]),
            .init(name: "Client et correctifs", lines: ["Chat en partie plus lisible. Retour du mode streamer. Corrections de stabilité et de l’interface sur PC et mobile."])
        ]),
        .init(patch: "18.5", published: "20 octobre 2026", summary: "Ajustements ciblés des champions en difficulté après le patch 18.4. Les mises à jour intermédiaires figurent dans les notes officielles.", groups: [])
    ]
}

struct PatchHubView: View {
    @EnvironmentObject private var meta: MetaStore
    @EnvironmentObject private var news: RiotNewsStore
    @State private var importing = false
    var body: some View {
        List {
            Section { PatchPicker() }
            switch meta.selection.channel {
            case .live:
                Section("Production") {
                    LabeledContent("Patch TFT associé", value: meta.live?.pack.patch ?? "À confirmer")
                    if let context = meta.context {
                        LabeledContent("Version EUW des ressources Riot", value: meta.euwVersion ?? context.euwAssetVersion)
                        LabeledContent("Build du Codex", value: meta.live?.reference?.version ?? context.liveBuild)
                    }
                    Text("La version des ressources EUW sert à vérifier la correspondance du Codex. L’heure de déploiement reste à confirmer auprès de Riot.").font(.caption).foregroundStyle(.secondary)
                }
                notesSection(patch: meta.live?.pack.patch)
            case .pbe:
                Section("Laboratoire PBE") {
                    LabeledContent("Build expérimental", value: meta.experimental?.version ?? "Indisponible")
                    if let date = meta.experimental?.retrievedAt { LabeledContent("Date du relevé", value: String(date.prefix(10))) }
                    if let checked = meta.pbeCheckedAt { LabeledContent("Dernière vérification", value: checked.formatted()) }
                    if let message = meta.pbeMessage { Text(message).font(.caption).foregroundStyle(.orange) }
                    if let current = meta.experimental, !meta.experimentalHistory.isEmpty {
                        ForEach(meta.experimentalHistory, id: \.version) { previous in
                            NavigationLink("Comparer au build " + previous.version) {
                                PatchDiffView(left: previous, right: current, leftLabel: "PBE archivé")
                            }
                        }
                    }
                    Text("Relevé du client par CommunityDragon. Les écarts du comparateur décrivent deux instantanés. Les changements peuvent encore évoluer.").font(.caption)
                    Link("Journal de Tactics.tools", destination: URL(string: "https://tactics.tools/info/pbe")!)
                    Link("Consulter le relevé PBE original", destination: URL(string: "https://raw.communitydragon.org/pbe/cdragon/tft/")!)
                    NavigationLink("Codex expérimental") { CodexView() }
                }
            case .archives:
                notesSection(patch: meta.archive?.pack.patch)
                if let archive = meta.archive {
                    Section("Instantané conservé") {
                        LabeledContent("Patch", value: archive.pack.patch ?? "—")
                        LabeledContent("Compositions", value: String(archive.pack.data.count))
                        LabeledContent("Collecte", value: String(archive.pack.retrievedAt?.prefix(10) ?? "—"))
                    }
                }
            }
            if let recent = news.patches {
                Section("Dernières publications Riot") {
                    Text("Vérifié le \(recent.checked.formatted())").font(.caption).foregroundStyle(.secondary)
                    ForEach(recent.articles.prefix(8)) { article in Link(article.title, destination: article.url) }
                }
            }
            Section("Comparer et préparer") {
                if let live = meta.live?.reference, let pbe = meta.experimental {
                    NavigationLink("Comparer LIVE et PBE") { PatchDiffView(left: live, right: pbe) }
                }
                if let live = meta.live {
                    ForEach(meta.archives.filter { $0.pack.set == live.pack.set && $0.sourceName == live.sourceName && !live.pack.data.isEmpty }) { archive in
                        NavigationLink("Méta \(archive.pack.patch ?? "—") et LIVE") { MetaComparisonView(old: archive, new: live) }
                    }
                }
                NavigationLink("Calendrier officiel") { PatchCalendarView() }
                Button("Importer un instantané archivable") { importing = true }
            }
        }.navigationTitle("Patches")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): meta.importArchive(url)
            case .failure(let error): meta.report(error.localizedDescription)
            }
        }
        .alert("Instantané", isPresented: Binding(get: { meta.archiveMessage != nil }, set: { if !$0 { meta.report(nil) } })) {
            Button("Fermer", role: .cancel) { meta.report(nil) }
        } message: { Text(meta.archiveMessage ?? "") }
    }
    @ViewBuilder private func notesSection(patch: String?) -> some View {
        Section("Notes officielles") {
            if let note = PatchNote.notes.first(where: { $0.patch == patch }) {
                NavigationLink("Notes du patch " + note.patch) { PatchNoteView(note: note) }
            } else { Text("Résumé natif indisponible pour ce patch.").foregroundStyle(.secondary) }
            Link("Toutes les notes Riot", destination: URL(string: "https://teamfighttactics.leagueoflegends.com/fr-fr/news/game-updates/")!)
        }
    }
}

struct PatchNoteView: View {
    let note: PatchNote
    var body: some View {
        List {
            Section("Riot Games · \(note.published)") {
                Text(note.summary)
                Link("Lire les notes officielles complètes", destination: note.url)
            }
            ForEach(note.groups) { group in
                Section(group.name) { ForEach(group.lines, id: \.self) { Text($0).font(.subheadline) } }
            }
        }.navigationTitle("Patch " + note.patch)
    }
}

struct PatchCalendarView: View {
    var body: some View {
        List {
            Section("Planning Riot · dates annoncées") {
                LabeledContent("18.7", value: "11 novembre 2026")
                LabeledContent("19.1 · nouveau set", value: "1 décembre 2026")
                LabeledContent("19.2", value: "15 décembre 2026")
                Link("Vérifier le calendrier Riot", destination: URL(string: "https://support.riotgames.com/en-us/tft/events/patch-schedule-teamfight-tactics")!)
            }
        }.navigationTitle("Calendrier TFT")
    }
}

struct PatchDiffView: View {
    let left: ReferenceData
    let right: ReferenceData
    var leftLabel = "LIVE"
    @State private var query = ""
    @State private var kind = "Tous"
    private var changes: [ReferenceChange] {
        ReferenceChange.compare(left, right).filter { (kind == "Tous" || $0.kind == kind) && (query.isEmpty || $0.name.localizedStandardContains(query)) }
    }
    var body: some View {
        List {
            Section {
                LabeledContent(leftLabel, value: left.version)
                LabeledContent("PBE expérimental", value: right.version)
                Picker("Catégorie", selection: $kind) {
                    Text("Toutes").tag("Tous"); Text("Champions").tag("champion"); Text("Traits").tag("trait")
                    Text("Objets").tag("item"); Text("Optimisations").tag("augment")
                }
                Text("Comparaison des libellés, coûts et recettes présents dans les exports. Les valeurs absentes des exports ne sont pas déduites.").font(.caption)
            }
            if changes.isEmpty {
                ContentUnavailableView("Aucun écart dans cette sélection", systemImage: "equal.circle")
            }
            ForEach(changes) { change in
                NavigationLink {
                    List {
                        if change.old != nil, change.new != nil, !change.changedStats.isEmpty {
                            Section("Valeurs du client") {
                                ForEach(change.changedStats, id: \.self) { key in
                                    LabeledContent(statName(key), value: formatted(change.old?.balance?[key]) + " → " + formatted(change.new?.balance?[key]))
                                }
                            }
                        }
                        Section(leftLabel) { if let entry = change.old { entryText(entry) } else { Text("Absent") } }
                        Section("PBE") { if let entry = change.new { entryText(entry) } else { Text("Absent") } }
                    }.navigationTitle(change.name)
                } label: { LabeledContent(change.name, value: change.status) }
            }
        }.searchable(text: $query).navigationTitle("LIVE et PBE")
    }
    private func statName(_ key: String) -> String {
        ["hp":"PV", "initialMana":"Mana initial", "mana":"Mana maximal", "damage":"Dégâts d’attaque",
         "attackSpeed":"Vitesse d’attaque", "armor":"Armure", "magicResist":"Résistance magique", "range":"Portée"][key] ?? key
    }
    private func formatted(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(0...3))) ?? "—"
    }
    private func entryText(_ entry: ReferenceEntry) -> some View {
        VStack(alignment: .leading) {
            if entry.kind == "champion" { Text("Coût \(entry.cost) PO") }
            Text(entry.description.isEmpty ? "Aucune description fournie" : entry.description)
        }
    }
}

struct MetaComparisonView: View {
    let old: PatchSnapshot
    let new: PatchSnapshot
    private var previous: [String: MetaComp] {
        Dictionary(old.pack.data.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
    }
    var body: some View {
        List {
            Section {
                Text("\(old.pack.patch ?? "—") → \(new.pack.patch ?? "—") · Blitz")
                Text("Les listes sont rapprochées par identifiant de composition Blitz. Chaque placement et volume provient de son propre échantillon.").font(.caption)
            }
            Section("Correspondances") {
                ForEach(new.pack.data.filter { previous[$0.slug] != nil }) { comp in
                    if let older = previous[comp.slug] {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(comp.title(new.reference)).font(.headline)
                            Text("\(older.tier) → \(comp.tier) · moyenne \(older.stats.avg_placement, format: .number.precision(.fractionLength(2))) → \(comp.stats.avg_placement, format: .number.precision(.fractionLength(2)))")
                            Text("\(older.stats.nb_games.formatted()) → \(comp.stats.nb_games.formatted()) parties").font(.caption).foregroundStyle(.secondary)
                            if Set(older.carry_units ?? []) != Set(comp.carry_units ?? []) { Text("Carries différents").font(.caption) }
                            if Set(older.units.flatMap { $0.items ?? [] }) != Set(comp.units.flatMap { $0.items ?? [] }) { Text("Équipements différents").font(.caption) }
                        }
                    }
                }
            }
            Section("Nouvelles dans ce relevé") {
                ForEach(new.pack.data.filter { previous[$0.slug] == nil }) { Text($0.title(new.reference)) }
            }
            Section("Absentes du relevé récent") {
                ForEach(old.pack.data.filter { older in !new.pack.data.contains { $0.slug == older.slug } }) { Text($0.title(old.reference)) }
            }
        }.navigationTitle("Évolution de la méta")
    }
}
