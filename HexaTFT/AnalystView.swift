import SwiftUI
import Charts

struct AnalystView: View {
    @EnvironmentObject private var tracker: TrackerStore
    @EnvironmentObject private var coach: AnalystStore
    @State private var set: Int?
    @State private var patch: String?
    @State private var window = 30
    @State private var section = "Bilan"
    @State private var eraseMemory = false
    private var activeSet: Int? { self.set ?? tracker.profile?.currentSet ?? tracker.profile?.matches.first?.set }
    private var account: String { tracker.state.selected ?? "" }
    private var all: [TrackedMatch] { activeSet.map { tracker.matches(set: $0) } ?? [] }
    private var report: MatchAnalyst { MatchAnalyst(matches: all, set: activeSet, patch: patch, limit: window) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let profile = tracker.profile {
                    intro(profile)
                    selection
                    Picker("Rubrique de l’analyste", selection: $section) {
                        ForEach(["Bilan", "Porteurs", "Parcours", "Dialogue"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("analyst-sections")
                    switch section {
                    case "Porteurs": CarryAnalysisView(report: report)
                    case "Parcours": SeasonJourneyView(report: report, account: account)
                    case "Dialogue": AnalystDialogueView(report: report, account: account)
                    default: balance
                    }
                    if let error = coach.error { Text(error).font(.caption).foregroundStyle(.orange) }
                } else {
                    ContentUnavailableView("Ton analyste personnel", systemImage: "sparkle.magnifyingglass", description: Text("Associe ton Riot ID et ton serveur dans Tracker. L’analyse des parties terminées reste locale sur l’iPhone."))
                    NavigationLink("Ajouter mon compte") { TrackerView() }.buttonStyle(.borderedProminent)
                }
            }.padding()
        }.background(hexaNavy).navigationTitle("Analyse")
            .task(id: activeSet) { if let activeSet { await tracker.loadArchive(set: activeSet) } }
            .onChange(of: set) { _, _ in patch = nil }
            .confirmationDialog("Effacer les objectifs, les notes et le dialogue de ce compte ?", isPresented: $eraseMemory, titleVisibility: .visible) {
                Button("Effacer ma mémoire d’analyse", role: .destructive) { coach.erase(account: account) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await tracker.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(tracker.busy).accessibilityLabel("Actualiser les parties")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { eraseMemory = true } label: { Image(systemName: "lock.shield") }.accessibilityLabel("Gérer ma mémoire locale")
                }
            }
    }
    private func intro(_ profile: RiotProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ANALYSTE PERSONNEL", systemImage: "sparkle.magnifyingglass").font(.caption.bold()).tracking(1).foregroundStyle(.mint)
            Text("Comprendre.\nPuis progresser.").font(.largeTitle.bold())
            Text(profile.riotID + " · " + profile.region.uppercased()).font(.subheadline.bold())
            Text("Des faits issus de tes matchs, des pistes expliquées et une priorité pour la prochaine session.").font(.subheadline).foregroundStyle(.secondary)
            HStack { Badge(text: "Calculs locaux", color: .mint); Badge(text: "Matchs terminés", color: hexaGold) }
            if let declared = profile.ranks.first(where: { $0.queue == "RANKED_TFT" })?.games, let indexed = profile.indexedGames, declared != indexed {
                Text("\(declared) parties déclarées au rang · \(indexed) dans le résumé de la source. Les dénominateurs restent séparés.").font(.caption).foregroundStyle(.secondary)
            }
            if let checked = profile.checkedAt { Text("Compte vérifié le " + checked.formatted(date: .abbreviated,time: .shortened)).font(.caption2).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(LinearGradient(colors: [.mint.opacity(0.16), .white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 25))
    }
    private var selection: some View {
        Panel {
            HStack {
                Menu {
                    ForEach(tracker.knownSets, id: \.self) { value in Button("Set \(value)") { set = value } }
                } label: { Label("Set \(activeSet ?? 0)", systemImage: "square.stack").font(.headline) }
                    .accessibilityIdentifier("analyst-set")
                Spacer()
                Menu {
                    Picker("Fenêtre", selection: $window) { ForEach([10,20,30,100,10000], id: \.self) { Text($0 == 10000 ? "Tout l’historique reçu" : "\($0) parties").tag($0) } }
                    Picker("Patch", selection: $patch) {
                        Text("Tous les patches de ce set").tag(nil as String?)
                        ForEach(Set(all.compactMap(\.patch)).sorted(), id: \.self) { Text($0).tag(Optional($0)) }
                    }
                } label: { Label("Filtres", systemImage: "line.3.horizontal.decrease.circle") }
            }
            Text("Solo classé · \(report.summary.count) parties reçues" + (patch.map { " · patch " + $0 } ?? " · tous patches du set"))
                .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("analyst-scope")
            if let activeSet, tracker.archiveLoading.contains(activeSet) { ProgressView("Import de l’archive…") }
            if let message = tracker.archiveMessage { Text(message).font(.caption).foregroundStyle(.orange) }
            Text("Les relevés publics arrivent au rythme du fournisseur. Les matchs reçus s’accumulent sans limite de 30 dans le stockage local.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var balance: some View {
        VStack(alignment: .leading, spacing: 18) {
            AnalysisMetricsView(summary: report.summary)
            if report.matches.isEmpty {
                ContentUnavailableView("Pas de match détaillé reçu", systemImage: "clock.badge.questionmark", description: Text("Les anciens rangs restent accessibles dans Parcours. Une archive peut ne fournir que ses agrégats."))
            } else {
                PlacementDistribution(matches: report.matches)
                Text("Tes points de travail").font(.title2.bold())
                Text(report.overview).font(.subheadline).foregroundStyle(.secondary)
                ForEach(report.findings.prefix(3)) { finding in
                    NavigationLink { FindingDetailView(finding: finding, report: report, account: account) } label: {
                        FindingCard(finding: finding)
                    }.buttonStyle(.plain).accessibilityIdentifier("finding-" + finding.id)
                }
                if report.findings.isEmpty { Text("Ces règles ne détectent pas de signal sur ce corpus. Cela ne signifie pas que toutes les décisions étaient optimales.").font(.caption) }
                Text("Tes dernières parties").font(.title2.bold())
                ForEach(report.matches.prefix(10)) { match in
                    NavigationLink { MatchAnalysisView(match: match, account: account) } label: { AnalysisMatchRow(match: match) }.buttonStyle(.plain)
                        .accessibilityIdentifier("analysis-match-" + match.id)
                }
                ShareLink(item: exportText) { Label("Exporter mon bilan", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
            }
        }
    }
    private var exportText: String {
        let s = report.summary
        return "HEXA · Bilan personnel · Set \(activeSet ?? 0) · Solo classé\n\(s.count) matchs, moyenne \(String(format:"%.2f",s.average)), \(s.top4) top 4, \(s.bottoms) places 7–8.\n\n" + report.findings.map { $0.title + "\n" + $0.fact + "\n" + $0.interpretation + "\nLimite : " + $0.limitation }.joined(separator: "\n\n")
    }
}

struct AnalysisMetricsView: View {
    let summary: AnalysisSummary
    var body: some View {
        HStack(spacing: 10) {
            metric("Moyenne", summary.count == 0 ? "—" : String(format: "%.2f", summary.average), hexaGold)
            metric("Top 4", "\(summary.top4)/\(summary.count)", .mint)
            metric("7e–8e", "\(summary.bottoms)", .orange)
        }.accessibilityIdentifier("analyst-metrics")
    }
    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value).font(.title2.bold()).monospacedDigit().foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct PlacementDistribution: View {
    let matches: [TrackedMatch]
    var body: some View {
        Panel {
            Label("La régularité de tes places", systemImage: "chart.bar.fill").font(.headline)
            Chart(1...8, id: \.self) { place in
                BarMark(x: .value("Place", String(place)), y: .value("Matchs", matches.filter { $0.placement == place }.count))
                    .foregroundStyle(place <= 4 ? Color.mint.gradient : Color.orange.gradient).cornerRadius(4)
            }.frame(height: 155).accessibilityLabel("Distribution des huit places sur \(matches.count) matchs")
            Text("\(matches.count) matchs · les petites séries restent exploratoires").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct FindingCard: View {
    let finding: AnalysisFinding
    var body: some View {
        Panel {
            HStack(alignment: .top) {
                Image(systemName: finding.category.symbol).font(.title2).foregroundStyle(hexaGold)
                VStack(alignment: .leading, spacing: 6) { Text(finding.title).font(.headline); Text(finding.fact).font(.subheadline).foregroundStyle(.secondary) }
                Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption)
            }
            HStack { Badge(text: "\(finding.evidence.count) matchs", color: .mint); Text("Voir les faits et les limites").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct FindingDetailView: View {
    @EnvironmentObject private var coach: AnalystStore
    @EnvironmentObject private var tracker: TrackerStore
    let finding: AnalysisFinding
    let report: MatchAnalyst
    let account: String
    @State private var saved = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(finding.title).font(.largeTitle.bold())
                Panel { Label("Fait observé", systemImage: "checkmark.seal").font(.headline).foregroundStyle(.mint); Text(finding.fact) }
                Panel { Label("Piste à examiner", systemImage: "lightbulb").font(.headline).foregroundStyle(hexaGold); Text(finding.interpretation); Text(finding.limitation).font(.caption).foregroundStyle(.secondary) }
                Panel {
                    Label("Exercice de la prochaine session", systemImage: "target").font(.headline)
                    Text(finding.exercise)
                    Button(saved ? "Objectif enregistré" : "Travailler ce point sur 10 parties") { coach.start(finding.category, account: account, report: report); saved = coach.error == nil }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("analyst-start-goal")
                        .disabled(report.set != (tracker.profile?.currentSet ?? tracker.profile?.matches.first?.set))
                }
                Text("Les matchs qui soutiennent ce constat").font(.title2.bold())
                ForEach(finding.evidence) { match in NavigationLink { MatchAnalysisView(match: match, account: account) } label: { AnalysisMatchRow(match: match) }.buttonStyle(.plain) }
            }.padding()
        }.background(hexaNavy).navigationTitle("Les preuves").navigationBarTitleDisplayMode(.inline)
    }
}

struct MatchUnitPortrait: View {
    @EnvironmentObject private var meta: MetaStore
    let unit: TrackedMatch.Unit
    let match: TrackedMatch
    var size: CGFloat = 42
    private var entry: ReferenceEntry {
        meta.matchReference(match)?.champion(key: unit.key) ?? ReferenceEntry(id: "champion:" + unit.key, name: unit.displayName, kind: "champion", set: String(match.set ?? 0), cost: unit.cost ?? 0, description: "", imageURL: unit.imageURL ?? "")
    }
    var body: some View { EntryIcon(entry: entry, size: size).accessibilityLabel(entry.name) }
}

struct AnalysisMatchRow: View {
    let match: TrackedMatch
    private var equipped: [TrackedMatch.Unit] { Array(match.units.sorted { $0.completeItems.count > $1.completeItems.count }.prefix(4)) }
    var body: some View {
        HStack(spacing: 12) {
            Text("\(match.placement)").font(.title.bold()).foregroundStyle(match.placement <= 4 ? .mint : .orange).frame(width: 34)
            VStack(alignment: .leading, spacing: 8) {
                Text(match.date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.bold())
                HStack(spacing: 5) { ForEach(Array(equipped.enumerated()), id: \.offset) { _, unit in MatchUnitPortrait(unit: unit, match: match, size: 31) } }
                Text("Niv. \(match.level.map(String.init) ?? "—") · \(match.goldLeft.map(String.init) ?? "—") PO · patch \(match.patch ?? "—")").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }.padding(14).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct MatchAnalysisView: View {
    @EnvironmentObject private var coach: AnalystStore
    let match: TrackedMatch
    let account: String
    @State private var note = ""
    private var findings: [AnalysisFinding] { MatchAnalyst(matches: [match], set: match.set).findings }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FeatureBanner(eyebrow: "PARTIE TERMINÉE · SET \(match.set ?? 0)", title: "Top \(match.placement)", detail: match.date.formatted(date: .abbreviated, time: .shortened), icon: "sparkle.magnifyingglass", accent: match.placement <= 4 ? .mint : .orange)
                Text("Ce que ton plateau raconte").font(.title2.bold())
                Text("Plateau final observé · les positions et le déroulement ne sont pas fournis.").font(.caption).foregroundStyle(.secondary)
                if match.augmentsKnown == false { Label("Optimisations non fournies par la source", systemImage:"questionmark.circle").font(.caption).foregroundStyle(.secondary) }
                ForEach(findings) { finding in
                    Panel { Label(finding.title, systemImage: finding.category.symbol).font(.headline); Text(finding.fact); Text(finding.interpretation).font(.subheadline); Text(finding.limitation).font(.caption).foregroundStyle(.secondary) }
                }
                if findings.isEmpty { Text("Aucun signal de ces règles sur ce match. Le résultat seul ne permet pas de juger les décisions.").font(.subheadline) }
                Text("Porteurs et équipement").font(.title2.bold())
                ForEach(Array(match.units.enumerated()), id: \.offset) { _, unit in MatchEquipmentCard(unit: unit, match: match) }
                Panel {
                    Label("Mon contexte", systemImage: "square.and.pencil").font(.headline)
                    Text("Une note personnelle complète l’historique ; elle reste distincte des faits observés.").font(.caption).foregroundStyle(.secondary)
                    TextField("Copies, transition ou choix à revoir…", text: $note, axis: .vertical).lineLimit(3...6)
                        .accessibilityIdentifier("analyst-match-note")
                    Button("Enregistrer ma note") { coach.note(note, match: match.id, account: account) }.buttonStyle(.bordered)
                    if let error = coach.error { Text(error).font(.caption).foregroundStyle(.orange) }
                }
                NavigationLink("Tous les faits de la partie") { TrackedMatchView(match: match) }.buttonStyle(.bordered)
            }.padding()
        }.background(hexaNavy).navigationTitle("Analyse du match").navigationBarTitleDisplayMode(.inline)
            .onAppear { note = coach.state.notes[account + ":" + match.id] ?? "" }
    }
}

struct MatchEquipmentCard: View {
    let unit: TrackedMatch.Unit
    let match: TrackedMatch
    var body: some View {
        Panel {
            HStack(spacing: 12) {
                MatchUnitPortrait(unit: unit, match: match, size: 48)
                VStack(alignment: .leading, spacing: 4) { Text(unit.displayName).font(.headline); Text("\(unit.stars.map(String.init) ?? "?") ★ · \(unit.completeItems.count) objets complets").font(.caption).foregroundStyle(hexaGold) }
            }
            if let equipment = unit.equipment, !equipment.isEmpty {
                ForEach(Array(equipment.enumerated()), id: \.offset) { _, item in
                    DisclosureGroup {
                        if let effect = item.effect, !effect.isEmpty { Text(effect).font(.caption) }
                        if let recipe = item.components, !recipe.isEmpty { Text("Recette publiée · " + recipe.joined(separator: " + ")).font(.caption).foregroundStyle(.secondary) }
                    } label: {
                        HStack {
                            AsyncImage(url: URL(string: item.imageURL ?? "")) { im in im.resizable().scaledToFit() } placeholder: { Image(systemName: "diamond") }.frame(width: 28,height: 28)
                            Text(item.name).font(.subheadline)
                            Spacer(); Text(item.isComponent ? "Composant" : item.isComplete ? "Complet" : "Type inconnu").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            } else { Text(unit.items.isEmpty ? "Aucun objet reçu dans le relevé final." : "Ancien relevé : catégories d’objets inconnues. La prochaine synchronisation peut les compléter.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct CarryAnalysisView: View {
    let report: MatchAnalyst
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tes porteurs, au-delà du résultat").font(.title2.bold())
            Text("Unités avec au moins deux objets complets. Un même match peut alimenter plusieurs groupes.").font(.caption).foregroundStyle(.secondary)
            ForEach(report.cohorts) { group in
                NavigationLink { CarryEvidenceView(group: group) } label: {
                    Panel {
                        let s = AnalysisSummary(matches: group.matches)
                        HStack { Text(group.name).font(.headline); Spacer(); Text("\(s.top4)/\(s.count) top 4").foregroundStyle(.mint) }
                        Text("Moyenne \(String(format:"%.2f",s.average)) · \(group.oneStar.count) à 1★ · \(group.improved.count) à 2★ ou plus").font(.caption).foregroundStyle(.secondary)
                        if s.count < 10 { Badge(text: "Petit échantillon", color: hexaGold) }
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("analysis-carry-" + group.id)
            }
            if report.cohorts.isEmpty { ContentUnavailableView("Pas assez d’équipement documenté", systemImage: "diamond", description: Text("Les catégories manquantes ne sont pas comptées comme objets complets.")) }
        }
    }
}

struct CarryEvidenceView: View {
    @EnvironmentObject private var tracker: TrackerStore
    let group: CarryCohort
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(group.name).font(.largeTitle.bold())
                cohort("1 étoile", group.oneStar)
                cohort("2 étoiles ou plus", group.improved)
                Text("Comparaison descriptive. Les objets, soutiens et circonstances peuvent expliquer une partie de l’écart. Ces groupes ne prédisent pas la prochaine place.").font(.caption).foregroundStyle(.secondary)
                ForEach(group.matches) { match in NavigationLink { MatchAnalysisView(match: match, account: tracker.state.selected ?? "") } label: { AnalysisMatchRow(match: match) }.buttonStyle(.plain) }
            }.padding()
        }.background(hexaNavy).navigationTitle("Les étoiles et les résultats").navigationBarTitleDisplayMode(.inline)
    }
    private func cohort(_ label: String, _ matches: [TrackedMatch]) -> some View {
        Panel {
            let s = AnalysisSummary(matches: matches)
            Text(label).font(.headline)
            AnalysisMetricsView(summary: s)
            if s.count > 0 { Text("Top 4 · intervalle de Wilson à 95 % : \(Int(s.interval.lowerBound*100))–\(Int(s.interval.upperBound*100)) %\nEffectif \(s.count). Cet intervalle ne corrige pas les biais de sélection.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct SeasonJourneyView: View {
    @EnvironmentObject private var tracker: TrackerStore
    @EnvironmentObject private var coach: AnalystStore
    let report: MatchAnalyst
    let account: String
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Ta progression se construit").font(.title2.bold())
            if let goal = coach.state.goals[account] {
                goalPanel(goal)
            } else {
                Text("Choisis un objectif avant la prochaine session. Son bilan s’appuie sur les nouveaux matchs du même set.").font(.subheadline).foregroundStyle(.secondary)
                ForEach(TrainingTopic.allCases) { topic in
                    Button { coach.start(topic, account: account, report: report) } label: { Panel { Label(topic.title,systemImage: topic.symbol).font(.headline); Text(topic.practice).font(.caption).foregroundStyle(.secondary) } }
                        .buttonStyle(.plain).disabled(report.set != (tracker.profile?.currentSet ?? tracker.profile?.matches.first?.set))
                }
            }
            Text("Le passeport de tes sets").font(.title2.bold())
            Text("Rangs publiés par OP.GG. Le nombre de matchs détaillés reçus peut différer du volume déclaré. Solo et Double Up restent séparés.").font(.caption).foregroundStyle(.secondary)
            ForEach(tracker.profile?.seasons ?? []) { season in
                Panel {
                    Text("SET " + season.number).font(.headline).foregroundStyle(hexaGold)
                    ForEach(season.ranks) { rank in
                        HStack { Text(rank.name).font(.caption); Spacer(); Text(rank.displayTier + " · \(rank.lp) LP").font(.subheadline.bold()) }
                        if let count = rank.games { Text("\(count) parties déclarées" + (rank.top4Count.map { " · \($0) succès publiés" } ?? "")).font(.caption).foregroundStyle(.secondary) }
                    }
                    if let value = Int(season.number) {
                        if let archive = tracker.archives.first(where: { $0.set == value }) {
                            Text("\(archive.matches.count) matchs solo détaillés reçus" + (archive.indexedGames.map { " · \($0) indexés par la source" } ?? "")).font(.caption).foregroundStyle(.mint)
                        }
                        Button("Consulter les données du set " + season.number) { Task { await tracker.loadArchive(set: value, force: true) } }.buttonStyle(.bordered)
                            .disabled(tracker.archiveLoading.contains(value))
                    }
                }
            }
        }
    }
    private func goalPanel(_ goal: TrainingGoal) -> some View {
        let added = Array(tracker.matches(set: goal.set).filter { $0.timestamp > goal.startedAt.timeIntervalSince1970 }.sorted { $0.timestamp < $1.timestamp }.prefix(10))
        return Panel {
            Label("Mon objectif · Set \(goal.set)", systemImage: "target").font(.headline).foregroundStyle(.mint)
            Text(goal.topic.title).font(.title3.bold()); Text(goal.topic.practice).font(.subheadline)
            ProgressView(value: Double(added.count), total: 10)
            Text("\(added.count)/10 nouvelles parties reçues").font(.caption)
            Text("Point de départ").font(.headline); AnalysisMetricsView(summary: AnalysisSummary(matches: goal.baseline))
            if !added.isEmpty { Text("Depuis le début de l’exercice").font(.headline); AnalysisMetricsView(summary: AnalysisSummary(matches: added)) }
            Text("L’historique final mesure le résultat, sans vérifier le moment exact des décisions. Les petites séries sont à confirmer.").font(.caption).foregroundStyle(.secondary)
            Button("Terminer cet objectif") { coach.stop(account: account) }.buttonStyle(.bordered)
        }.accessibilityIdentifier("analyst-active-goal")
    }
}

struct AnalystDialogueView: View {
    @EnvironmentObject private var coach: AnalystStore
    let report: MatchAnalyst
    let account: String
    @State private var question = ""
    private var messages: [AnalystMessage] { coach.state.conversations[coach.scope(account: account, report: report)] ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Parlons de tes parties").font(.title2.bold())
            Text("Analyste local · réponses calculées sur la sélection. Questions sur tes résultats, l’or, les étoiles et les objets. Aucun envoi vers un service d’IA.").font(.caption).foregroundStyle(.secondary)
            ForEach(["Pourquoi je perds des places ?", "Que montrent mes objets ?", "Quels porteurs me réussissent ?", "Que revoir dans mes dépenses d’or ?"], id: \.self) { prompt in
                Button(prompt) { coach.ask(prompt, account: account, report: report) }.buttonStyle(.bordered).tint(.mint)
            }
            HStack {
                TextField("Une question sur cette sélection…", text: $question, axis: .vertical).lineLimit(1...4).accessibilityIdentifier("analyst-question")
                Button { coach.ask(question,account: account,report: report); question = "" } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Poser ma question")
            }.padding(14).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:18))
            ForEach(messages.reversed()) { message in
                Panel {
                    Text(message.question).font(.headline).foregroundStyle(hexaGold)
                    if let context = message.context { Text(context + " · " + message.date.formatted(date:.abbreviated,time:.shortened)).font(.caption2).foregroundStyle(.secondary) }
                    Text(message.answer).font(.subheadline).textSelection(.enabled)
                    let evidence = message.evidence ?? report.matches.filter { message.matchIDs.contains($0.id) }
                    if !evidence.isEmpty {
                        DisclosureGroup("Voir les \(evidence.count) matchs cités") {
                            ForEach(evidence) { match in NavigationLink { MatchAnalysisView(match: match,account:account) } label: { AnalysisMatchRow(match:match) } }
                        }
                    }
                }.accessibilityIdentifier("analyst-answer")
            }
        }
    }
}
