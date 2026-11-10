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
    var url: URL { RiotPatchParser.url(patch) }

    struct ChangeGroup: Identifiable {
        let name: String
        let icon: String
        let changes: [Change]
        var id: String { name }
    }

    struct Change: Identifiable {
        enum Direction {
            case buff, nerf, update
            var label: String { switch self { case .buff: "Buff"; case .nerf: "Nerf"; case .update: "Mise à jour" } }
            var icon: String { switch self { case .buff: "arrow.up"; case .nerf: "arrow.down"; case .update: "wrench.adjustable" } }
            var color: Color { switch self { case .buff: .mint; case .nerf: .orange; case .update: .cyan } }
        }

        let title: String
        let detail: String
        let before: String?
        let after: String?
        let direction: Direction
        var id: String { title + detail }

        init(_ title: String, _ detail: String, _ before: String, _ after: String, _ direction: Direction) {
            self.title = title
            self.detail = detail
            self.before = before
            self.after = after
            self.direction = direction
        }

        init(_ title: String, _ detail: String) {
            self.title = title
            self.detail = detail
            before = nil
            after = nil
            direction = .update
        }
    }

    static let notes: [Self] = [
        .init(patch: "18.6", published: "3 novembre 2026", summary: "Client TFT autonome, renforts pour plusieurs unités à quatre PO et deux vagues de correctifs sur PC et mobile.", groups: [
            .init(name: "Traits", icon: "sparkles", changes: [
                .init("Fleur spirituelle", "Bonus de dégâts d’attaque et de puissance", "12 / 30 / 50 / 55 %", "12 / 30 / 55 / 65 %", .buff),
                .init("Sylvestre", "PV bonus au palier 9", "25 %", "10 %", .nerf),
                .init("Ami de la forêt", "Bonus de dégâts d’attaque et de puissance du partenaire à distance", "15 / 28 / 33 %", "15 / 30 / 38 %", .buff)
            ]),
            .init(name: "Champions", icon: "person.2", changes: [
                .init("Kobuko", "Soins", "285 / 335 / 480", "300 / 350 / 550", .buff),
                .init("Rek’Sai", "Soins", "10 / 14 / 20", "10 / 16 / 24", .buff),
                .init("Lycan", "Dégâts des attaques renforcées", "65 / 100 / 160", "65 / 100 / 180", .buff),
                .init("Malphite", "Bouclier", "735 / 885 / 2 000", "750 / 925 / 2 000", .buff),
                .init("Malphite", "Dégâts de compétence", "40 / 60 / 2 000", "100 / 150 / 2 000", .buff),
                .init("Nidalee AD", "Soins", "300 / 450 / 2 000", "325 / 550 / 2 000", .buff),
                .init("Nidalee AD", "Bonus de la troisième incantation", "125 %", "140 %", .buff),
                .init("Nidalee AP", "Dégâts des attaques renforcées", "185 / 275 / 2 000", "195 / 295 / 2 000", .buff),
                .init("Nidalee AP", "Dégâts de la troisième attaque", "330 / 500 / 3 000", "350 / 525 / 3 000", .buff),
                .init("Sentinelle", "Part des PV dans le bouclier", "10 %", "12 %", .buff)
            ]),
            .init(name: "Optimisations", icon: "diamond", changes: [
                .init("Accélérateur mécanique", "Vitesse d’attaque par activation", "10 %", "12 %", .buff),
                .init("Agrandissement", "Bonus de dégâts d’attaque et de puissance des fées", "50 %", "35 %", .nerf),
                .init("Résistance acharnée", "Résistances de base", "8", "10", .buff),
                .init("Shopping intensif", "Or de départ", "6 PO", "7 PO", .buff),
                .init("Sans rival", "Soins partagés par Rengar", "25 %", "50 %", .buff),
                .init("Sans rival", "Mana partagé par Kha’Zix", "50 %", "70 %", .buff)
            ]),
            .init(name: "Esprits de la forêt", icon: "leaf", changes: [
                .init("Chariot de curiosités", "Prix d’un emblème", "15 PO", "17 PO", .nerf),
                .init("Cheminement", "Prix de base", "4 PO", "5 PO", .nerf),
                .init("Cheminement", "Prix de l’amélioration", "3 PO", "4 PO", .nerf)
            ]),
            .init(name: "Client et correctifs", icon: "desktopcomputer", changes: [
                .init("Client TFT autonome", "Le lancement sépare TFT du client partagé. Riot prévoit de poursuivre les améliorations avec le 18.7 et le set 19."),
                .init("Interface en jeu", "Messagerie plus lisible, retour du mode streamer et indication plus visible des boutons d’achat d’XP et de relance sur PC."),
                .init("Correctifs du 6 novembre", "Multitâche mobile jusqu’à deux minutes, récupération des récompenses du passe et corrections d’affichage des optimisations."),
                .init("Correctifs annoncés les 6 et 10 novembre", "Riot traite aussi les échecs de matchmaking, la mise au premier plan au lancement d’une file et les icônes de profil invisibles."),
                .init("Cosmétiques des prochains patches", "La séparation des nouvelles petites légendes est prévue en 19.1 et celle des nouvelles emotes en 19.2.")
            ])
        ]),
        .init(patch: "18.5", published: "20 octobre 2026", summary: "Ajustements ciblés des verticales et du haut de tableau. Les correctifs du 22 et du 27 octobre ont surtout touché Roncier, Kha’Zix et Main de la justice.", groups: [
            .init(name: "Traits", icon: "sparkles", changes: [
                .init("Ronce-obscure", "Bonus du palier 6", "60 %", "50 %", .nerf),
                .init("Sylvestre", "PV bonus des invocations au palier 9", "140 %", "125 %", .nerf),
                .init("Fæ", "Soins aux paliers 2 et 4", "2,5 / 4 %", "3 / 5 %", .buff),
                .init("Flora fatalis", "Soin en pourcentage des PV max", "8 %", "7 %", .nerf),
                .init("Ultrarapide", "Vitesse d’attaque par attaque", "3 / 5 / 8 / 12 %", "3 / 5 / 7 / 10 %", .nerf),
                .init("Jungle", "Bonus de dégâts et puissance au palier 7", "6 %", "5 %", .nerf)
            ]),
            .init(name: "Champions", icon: "person.2", changes: [
                .init("Caitlyn", "Dégâts des attaques renforcées", "190 / 285 / 470", "200 / 300 / 490", .buff),
                .init("Azir", "Dégâts de compétence", "46 / 69 / 110", "43 / 65 / 105", .nerf),
                .init("Tristana", "Coût en mana du sort", "60", "50", .buff),
                .init("Morgana", "Dégâts initiaux de la malédiction", "60 / 90", "70 / 105", .buff),
                .init("Sentinelle", "Durée de l’étourdissement", "1 s", "0,5 s", .nerf),
                .init("Sentinelle", "Bouclier", "350 / 450", "375 / 475", .buff),
                .init("Sett", "PV rendus via la puissance", "225 / 275", "250 / 300", .buff),
                .init("Taric", "Armure et résistance magique", "65", "70", .buff)
            ]),
            .init(name: "Correctifs du 22 et 27 octobre", icon: "calendar.badge.clock", changes: [
                .init("Roncier · 22 oct.", "Soins de la Marque alpha à l’impact", "5 %", "4 %", .nerf),
                .init("Roncier · 27 oct.", "Armure ignorée par le ratio", "25 %", "10 %", .nerf),
                .init("Roncier · 27 oct.", "Armure ignorée de base", "25 %", "30 %", .buff),
                .init("Kha’Zix · 27 oct.", "Dégâts sur les cibles isolées", "280 / 390 / 590", "250 / 350 / 530", .nerf),
                .init("Main de la justice · 27 oct.", "Omnivampirisme", "15 %", "12 %", .nerf),
                .init("Main de la justice de la lumière · 27 oct.", "Omnivampirisme", "30 %", "25 %", .nerf)
            ])
        ])
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
                    FeatureBanner(eyebrow: "RELEASE NOTES · LIVE EUW", title: "Patch " + (meta.live?.pack.patch ?? "EUW"),
                                  detail: "Équilibrage, correctifs et prochains déploiements", icon: "bolt.horizontal.circle")
                        .listRowBackground(Color.clear)
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
                    FeatureBanner(eyebrow: "SERVEUR EXPÉRIMENTAL", title: "Laboratoire PBE",
                                  detail: "Versions du client, historique et changements à tester", icon: "flask", accent: .mint)
                        .listRowBackground(Color.clear)
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
                    ForEach(recent.articles.prefix(8)) { article in
                        if let patch = article.patchNumber {
                            NavigationLink(article.title) {
                                if let note = PatchNote.notes.first(where: { $0.patch == patch }) {
                                    PatchNoteView(note: note)
                                } else {
                                    RiotPatchArticleView(patch: patch)
                                }
                            }
                        } else { Link(article.title, destination: article.url) }
                    }
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
        }.scrollContentBackground(.hidden).background(hexaNavy).navigationTitle("Patches")
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
    @State private var category: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                FeatureBanner(eyebrow: "RIOT GAMES · " + note.published.uppercased(), title: "Patch " + note.patch,
                              detail: note.summary, icon: "doc.text.magnifyingglass")
                HStack {
                    DashboardMetric(title: "Catégories", value: note.groups.count.formatted())
                    DashboardMetric(title: "Changements détaillés", value: note.groups.flatMap(\.changes).count.formatted(), accent: .mint)
                }.padding(.horizontal, 6)
                Picker("Catégorie", selection: $category) {
                    Text("Toutes les catégories").tag(nil as String?)
                    ForEach(note.groups) { Text($0.name).tag(Optional($0.id)) }
                }.buttonStyle(.bordered).accessibilityIdentifier("patch-category")
                ForEach(note.groups.filter { category == nil || $0.id == category }) { group in
                    Label(group.name, systemImage: group.icon).font(.title3.bold())
                    ForEach(group.changes) { change in changeRow(change) }
                }
                Link(destination: note.url) { Label("Notes Riot complètes en français", systemImage: "arrow.up.right.square") }
                    .buttonStyle(.bordered)
            }.padding()
        }.background(hexaNavy).navigationTitle("Patch " + note.patch).navigationBarTitleDisplayMode(.inline)
    }
    private func changeRow(_ change: PatchNote.Change) -> some View {
        Panel {
            HStack(alignment: .top) {
                Text(change.title).font(.headline)
                Spacer()
                Label(change.direction.label, systemImage: change.direction.icon)
                    .font(.caption.bold()).foregroundStyle(change.direction.color)
            }
            if change.detail != change.title { Text(change.detail).font(.subheadline).foregroundStyle(.secondary) }
            if let before = change.before, let after = change.after {
                HStack(alignment: .top) {
                    DashboardMetric(title: "Avant", value: before.replacingOccurrences(of: " %", with: "\u{00A0}%"), accent: .secondary)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityHidden(true)
                    DashboardMetric(title: "Après", value: after.replacingOccurrences(of: " %", with: "\u{00A0}%"), accent: change.direction.color)
                }
            }
        }
    }
}


struct RiotPatchArticleView: View {
    let patch: String
    @State private var note: PatchNote?
    @State private var unavailable = false

    var body: some View {
        Group {
            if let note {
                PatchNoteView(note: note)
            } else if unavailable {
                ContentUnavailableView {
                    Label("Détail natif indisponible", systemImage: "doc.text")
                } actions: {
                    Link("Ouvrir les notes Riot", destination: RiotPatchParser.url(patch))
                }
            } else {
                ProgressView("Lecture des notes Riot")
            }
        }.navigationTitle("Patch " + patch)
        .task(id: patch) {
            guard note == nil else { return }
            let url = RiotPatchParser.url(patch)
            guard let data = try? await DragonFeed.get(url, max: 2_000_000),
                  let html = String(data: data, encoding: .utf8), !Task.isCancelled else {
                if !Task.isCancelled { unavailable = true }
                return
            }
            note = await Task.detached(priority: .utility) { RiotPatchParser.parse(html, patch: patch) }.value
            unavailable = note == nil
        }
    }
}

enum RiotPatchParser {
    static func url(_ patch: String) -> URL {
        URL(string: "https://teamfighttactics.leagueoflegends.com/fr-fr/news/game-updates/teamfight-tactics-patch-" + patch.replacingOccurrences(of: ".", with: "-") + "/")!
    }

    static func parse(_ html: String, patch: String) -> PatchNote? {
        let pattern = #"<(h[24])\b[^>]*>([^<]{1,200})</\1>|<li\b[^>]*>((?:(?!<(?:ul|ol|li)\b|</li>)[\s\S])*?)(?=<(?:ul|ol|li)\b|</li>)|</li>"#
        guard let tokens = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let input = html as NSString
        var heading = ""
        var subsection = ""
        var parents: [String] = []
        var order: [String] = []
        var sections: [String: [PatchNote.Change]] = [:]

        for token in tokens.matches(in: html, range: NSRange(location: 0, length: input.length)) {
            if token.range(at: 1).location != NSNotFound {
                let name = plain(input.substring(with: token.range(at: 2)))
                if input.substring(with: token.range(at: 1)).lowercased() == "h2" {
                    heading = name
                    subsection = ""
                } else { subsection = name }
                parents.removeAll()
            } else if token.range(at: 3).location != NSNotFound {
                let line = plain(input.substring(with: token.range(at: 3)))
                if !heading.isEmpty, let arrow = line.range(of: "⇒") ?? line.range(of: "→"),
                   let colon = line[..<arrow.lowerBound].lastIndex(of: ":") {
                    let before = line[line.index(after: colon)..<arrow.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                    let after = line[arrow.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    let detail = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
                    if before.count <= 80, after.count <= 80, detail.count <= 100,
                       before.contains(where: \.isNumber), after.contains(where: \.isNumber) {
                        let group = [heading, subsection].filter { !$0.isEmpty }.joined(separator: " · ")
                        let subject = parents.filter { !$0.isEmpty && $0.count <= 80 }.joined(separator: " · ")
                        let change = PatchNote.Change(subject.isEmpty ? detail : subject, detail, before, after, .update)
                        if sections[group] == nil { order.append(group) }
                        if sections[group]?.contains(where: { $0.id == change.id }) != true {
                            sections[group, default: []].append(change)
                        }
                    }
                    parents.append("")
                } else {
                    parents.append(line)
                }
            } else {
                _ = parents.popLast()
            }
        }

        let groups = order.compactMap { name in
            sections[name].map { PatchNote.ChangeGroup(name: name, icon: "slider.horizontal.3", changes: $0) }
        }
        guard !groups.isEmpty else { return nil }
        return PatchNote(patch: patch, published: "Publication officielle",
                         summary: "Valeurs d’équilibrage publiées par Riot. Consulte la note complète pour le contexte et les correctifs.",
                         groups: groups)
    }

    private static func plain(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#x27;", with: "’")
            .replacingOccurrences(of: "&#8658;", with: "⇒")
            .replacingOccurrences(of: "&rArr;", with: "⇒")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
    private var allChanges: [ReferenceChange] { ReferenceChange.compare(left, right) }
    private var changes: [ReferenceChange] {
        allChanges.filter { (kind == "Tous" || $0.kind == kind) && (query.isEmpty || $0.name.localizedStandardContains(query)) }
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
                HStack {
                    DashboardMetric(title: "Ajouts", value: allChanges.filter { $0.old == nil }.count.formatted(), accent: .mint)
                    DashboardMetric(title: "Modifications", value: allChanges.filter { $0.old != nil && $0.new != nil }.count.formatted())
                    DashboardMetric(title: "Retraits", value: allChanges.filter { $0.new == nil }.count.formatted(), accent: .orange)
                }
                Text("Les écarts portent sur les champs présents dans les exports du client.").font(.caption)
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
                            if let earlier = older.stats, let newer = comp.stats {
                                Text("\(older.tier) → \(comp.tier) · moyenne \(earlier.avg_placement, format: .number.precision(.fractionLength(2))) → \(newer.avg_placement, format: .number.precision(.fractionLength(2)))")
                                Text("\(earlier.nb_games.formatted()) → \(newer.nb_games.formatted()) parties").font(.caption).foregroundStyle(.secondary)
                            }
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
