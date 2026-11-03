import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct GuidesView: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var favoritesOnly = false
    @State private var importing = false
    private var filtered: [Guide] {
        store.guides.filter {
            (!favoritesOnly || store.state.favorites.contains($0.id)) &&
            (query.isEmpty || ($0.name + " " + $0.style + " " + $0.tags.joined(separator: " ")).localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Badge(text: "COMPAGNON PC → IPHONE"); Spacer() }
                Text("Un plan.\nPlusieurs chemins.").font(.largeTitle.bold())
                if let catalogue = store.catalogue {
                    Panel {
                        Label(catalogue.isDemo ? "Plans pédagogiques" : "Catalogue importé", systemImage: "info.circle")
                            .font(.headline).foregroundStyle(.mint)
                        Text(catalogue.isDemo ? "Ces exemples expliquent des styles de jeu. Ils ne représentent pas les compos méta du patch actuel." : "Source : \(catalogue.source)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("\(catalogue.patch) · Mis à jour le \(catalogue.updatedAt)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle("Mes favoris", isOn: $favoritesOnly)
                ForEach(filtered) { guide in
                    NavigationLink { GuideDetail(guide: guide) } label: {
                        Panel {
                            HStack {
                                Badge(text: guide.style)
                                Spacer()
                                Image(systemName: store.state.favorites.contains(guide.id) ? "star.fill" : "chevron.right")
                            }
                            Text(guide.name).font(.title2.bold()).foregroundStyle(.primary)
                            Text(guide.summary).font(.subheadline).foregroundStyle(.secondary)
                            Text("\(guide.difficulty) · 6 étapes").font(.caption).foregroundStyle(.mint)
                        }
                    }.buttonStyle(.plain)
                }
                if filtered.isEmpty { ContentUnavailableView.search(text: query) }
            }.padding()
        }
        .navigationTitle("Hexa").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Un plan, un style…")
        .toolbar { Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }.accessibilityLabel("Importer un catalogue JSON") }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result { case .success(let url): store.importCatalogue(url); case .failure(let error): store.error = error.localizedDescription }
        }
    }
}

struct GuideDetail: View {
    @EnvironmentObject private var store: Store
    let guide: Guide
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Badge(text: guide.style)
                Text(guide.name).font(.largeTitle.bold())
                Text(guide.summary).foregroundStyle(.secondary)
                Button { store.pin(guide) } label: {
                    Label(store.pinned?.id == guide.id ? "Plan épinglé dans Partie" : "Épingler dans Partie", systemImage: "pin.fill")
                        .frame(maxWidth: .infinity).padding(8)
                }.buttonStyle(.borderedProminent)
                Panel {
                    Text("Objets : principes").font(.headline)
                    ForEach(guide.itemNotes, id: \.self) { Text("• " + $0).font(.subheadline) }
                }
                Panel {
                    Text("Placement : principes").font(.headline)
                    ForEach(guide.positioning, id: \.self) { Text("• " + $0).font(.subheadline) }
                }
                ForEach(guide.phases) { PhasePanel(phase: $0) }
            }.padding()
        }
        .navigationTitle("Fiche de jeu").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { store.favorite(guide.id) } label: { Image(systemName: store.state.favorites.contains(guide.id) ? "star.fill" : "star") }
                .accessibilityLabel("Ajouter ou retirer des favoris")
        }
    }
}

struct PhasePanel: View {
    let phase: Phase
    var body: some View {
        Panel {
            HStack { Badge(text: phase.stage.rawValue); Text(phase.stage.title).font(.headline) }
            Text(phase.objective).font(.title3.weight(.semibold))
            Label(phase.level, systemImage: "arrow.up.right").font(.subheadline)
            Label(phase.economy, systemImage: "circle.circle").font(.subheadline).foregroundStyle(.yellow)
            Divider()
            ForEach(phase.options, id: \.self) { Text("• " + $0).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}

struct CompanionView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var meta: MetaStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var stayAwake = false
    @State private var active = false
    private func updateIdleTimer() { UIApplication.shared.isIdleTimerDisabled = active && stayAwake && scenePhase == .active }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let composition = meta.comps.first(where: { $0.id == store.state.pinnedID }) {
                    Text(composition.title(store.reference)).font(.title2.bold())
                    VisualCompositionGuide(comp: composition, stage: Binding(get: { store.state.stage }, set: { store.setStage($0) }))
                    EquipmentRoster(comp: composition)
                    NavigationLink("Guide complet et statistiques") { MetaDetail(comp: composition) }.buttonStyle(.bordered)
                    Toggle("Garder l’écran allumé ici", isOn: $stayAwake)
                } else if let guide = store.pinned {
                    Text(guide.name).font(.largeTitle.bold())
                    Text("Choisis l’étape à consulter. Le contenu est celui du guide, sans analyse de ta partie.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], spacing: 10) {
                        ForEach(Stage.allCases) { stage in
                            Button { store.setStage(stage) } label: {
                                Text(stage.rawValue).font(.title3.monospacedDigit().bold()).frame(maxWidth: .infinity).padding(.vertical, 12)
                            }.buttonStyle(.bordered).tint(stage == store.state.stage ? .mint : .gray)
                                .accessibilityAddTraits(stage == store.state.stage ? .isSelected : [])
                        }
                    }
                    if let phase = guide.phase(at: store.state.stage) { PhasePanel(phase: phase) }
                    NavigationLink("Voir le guide complet") { GuideDetail(guide: guide) }.buttonStyle(.bordered)
                    Toggle("Garder l’écran allumé ici", isOn: $stayAwake)
                    Text("L’étape sélectionnée et le plan épinglé sont sauvegardés sur cet iPhone.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("Ton plan à portée de main", systemImage: "pin",
                                           description: Text("Dans Méta, ouvre une composition et touche Suivre dans Partie."))
                }
            }.padding()
        }.background(hexaNavy).navigationTitle("À côté du PC").navigationBarTitleDisplayMode(.inline)
        .onAppear { active = true; updateIdleTimer() }
        .onDisappear { active = false; updateIdleTimer() }
        .onChange(of: stayAwake) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, _ in updateIdleTimer() }
    }
}
