import SwiftUI

struct SelectedGuideUnit: Identifiable { let id: String }
struct VisualCompositionGuide: View {
    @EnvironmentObject private var store: Store
    let comp: MetaComp
    @Binding var stage: Stage
    @State private var mode = "Stades"
    @State private var level = "6"
    @State private var option = 0
    @State private var selected: SelectedGuideUnit?
    private var boards: [GuideBoard] {
        switch mode {
        case "Final": return [comp.finalBoard]
        case "Niveaux": return comp.guideBoards(level: level)
        default: return comp.guideBoards(stage: stage)
        }
    }
    private var board: GuideBoard? { boards.indices.contains(option) ? boards[option] : boards.first }
    private var previous: GuideBoard? {
        guard mode == "Stades", let index = Stage.allCases.firstIndex(of: stage), index > 0 else { return nil }
        return comp.guideBoards(stage: Stage.allCases[index - 1]).first
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Guide visuel", systemImage: "point.3.connected.trianglepath.dotted").font(.title2.bold())
                Spacer()
                Text(comp.style).font(.caption.bold()).foregroundStyle(hexaGold)
            }
            Picker("Parcours du plateau", selection: $mode) {
                ForEach(["Stades", "Niveaux", "Final"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("guide-mode")
            if mode == "Stades" { VisualTimeline(stage: $stage) }
            if mode == "Niveaux" { levelPicker }
            if let board {
                Panel {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode == "Final" || board.isFinal ? "Plateau cible" : mode == "Niveaux" ? "Niveau " + level : stage.title).font(.title3.bold())
                            let champions = board.units.filter { store.champion("champion:" + $0.name) != nil }.count
                            let summons = board.units.count - champions
                            Text("\(champions) champions" + (summons > 0 ? " · \(summons) invocations" : "") + " · touche un portrait").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if boards.count > 1 {
                            Picker("Variante", selection: $option) {
                                ForEach(boards.indices, id: \.self) { Text("Option \($0+1)").tag($0) }
                            }.pickerStyle(.menu).accessibilityIdentifier("guide-variant")
                        }
                    }
                    if board.positions.isEmpty {
                        Label("Placement non fourni pour ce plateau", systemImage: "info.circle").font(.subheadline)
                        UnitStrip(units: board.units)
                    } else {
                        TacticalBoard(comp: comp, board: board, newUnits: board.keys.subtracting(previous?.keys ?? board.keys)) { selected = SelectedGuideUnit(id: $0) }
                    }
                    HStack(spacing: 12) {
                        Label("Nouveau", systemImage: "plus.circle.fill").foregroundStyle(.mint)
                        Label("Objet cible", systemImage: "circle.dashed").foregroundStyle(hexaGold)
                    }.font(.system(size: 10))
                    Text("Icônes pleines : objets observés. Pointillés : équipement visé ou à transférer, pas encore observé sur ce plateau.").font(.caption2).foregroundStyle(.secondary)
                    Text(board.sourceLabel).font(.caption2).foregroundStyle(.secondary)
                    if let sample = board.sample { Text("\(sample.formatted()) plateaux / parties dans cet exemple").font(.caption2).foregroundStyle(.secondary) }
                }
                if let previous, mode == "Stades", previous.keys != board.keys {
                    BoardComparison(previous: previous, current: board)
                }
                if mode == "Stades" {
                    Panel {
                        Label("Le plan à cette étape", systemImage: "flag.checkered").font(.headline)
                        Text(comp.economy(at: stage)).font(.subheadline).foregroundStyle(.secondary)
                        Text("Repères généraux du style · plateaux observés par la source").font(.caption2).foregroundStyle(.secondary)
                        HStack {
                            Button { advance(-1) } label: { Label("Précédente", systemImage: "chevron.left") }.disabled(stage == Stage.allCases.first)
                            Spacer()
                            Button { advance(1) } label: { Label("Suivante", systemImage: "chevron.right") }.disabled(stage == Stage.allCases.last)
                        }.buttonStyle(.bordered)
                    }
                }
            } else {
                ContentUnavailableView("Aucun exemple à ce niveau", systemImage: "hexagon", description: Text("Choisis un autre niveau ou le plateau final."))
            }
        }
        .onChange(of: stage) { _, _ in option = 0 }
        .onChange(of: level) { _, _ in option = 0 }
        .onChange(of: mode) { _, _ in option = 0 }
        .sheet(item: $selected) { selection in
            if let board { NavigationStack { ChampionEquipmentView(comp: comp, unitKey: selection.id, board: board) } }
        }
    }
    private var levelPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach((comp.variations?.levels?.keys.map { $0 } ?? []).sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }, id: \.self) { value in
                    Button("Niv. " + value) { level = value }.buttonStyle(.bordered).tint(level == value ? hexaGold : .gray).accessibilityIdentifier("guide-level-" + value)
                }
            }
        }
    }
    private func advance(_ offset: Int) {
        guard let index = Stage.allCases.firstIndex(of: stage), Stage.allCases.indices.contains(index + offset) else { return }
        stage = Stage.allCases[index + offset]
    }
}
struct VisualTimeline: View {
    @Binding var stage: Stage
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Stage.allCases.enumerated()), id: \.element.id) { index, value in
                        Button { withAnimation(.easeInOut(duration: 0.2)) { stage = value } } label: {
                            VStack(spacing: 6) {
                                Text("\(index+1)").font(.caption2.bold()).frame(width: 20, height: 20).background(stage == value ? hexaGold : .white.opacity(0.08), in: Circle()).foregroundStyle(stage == value ? hexaNavy : .secondary)
                                Text(value.rawValue).font(.headline.monospacedDigit())
                                Text(shortTitle(value)).font(.system(size: 10))
                            }.frame(width: 75).padding(.vertical, 10)
                                .background(stage == value ? hexaGold.opacity(0.14) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain).foregroundStyle(stage == value ? hexaGold : .secondary)
                            .id(value.id).accessibilityIdentifier("guide-stage-" + value.rawValue)
                            .accessibilityLabel("Stade \(value.rawValue), \(value.title)").accessibilityAddTraits(stage == value ? .isSelected : [])
                    }
                }
            }.onChange(of: stage) { _, value in withAnimation { proxy.scrollTo(value.id, anchor: .center) } }
        }
    }
    private func shortTitle(_ value: Stage) -> String {
        switch value { case .opening: return "Ouverture"; case .early: return "Début"; case .mid: return "Milieu"; case .transition: return "Transition"; case .late: return "Fin"; case .end: return "Final" }
    }
}
struct TacticalBoard: View {
    @EnvironmentObject private var store: Store
    let comp: MetaComp
    let board: GuideBoard
    var newUnits: Set<String> = []
    let select: (String) -> Void
    var body: some View {
        VStack(spacing: 6) {
            Label("ADVERSAIRE", systemImage: "arrow.up").font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(.secondary)
            GeometryReader { geometry in
                let width = (geometry.size.width - 22) / 7.5
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { col in
                                let position = board.positions.first { $0.board_position == row * 7 + col }
                                TacticalCell(comp: comp, board: board, unitKey: position?.unit_api_name, width: width, isNew: position.map { newUnits.contains($0.unit_api_name) } ?? false, select: select)
                            }
                        }.offset(x: row.isMultiple(of: 2) ? 0 : width / 2)
                    }
                }
            }.frame(height: cellHeight)
            HStack { Text("PREMIÈRE LIGNE ↑"); Spacer(); Text("ARRIÈRE ↓") }.font(.system(size: 8)).foregroundStyle(.secondary)
        }
    }
    // Width-dependent cell content reserves room for champion names and all 3 items.
    private var cellHeight: CGFloat { 345 }
}
struct TacticalCell: View {
    @EnvironmentObject private var store: Store
    let comp: MetaComp
    let board: GuideBoard
    let unitKey: String?
    let width: CGFloat
    let isNew: Bool
    let select: (String) -> Void
    private var entry: ReferenceEntry? { unitKey.map { store.champion("champion:" + $0) ?? ReferenceEntry.boardEntity($0) } }
    var body: some View {
        VStack(spacing: 3) {
            if let key = unitKey, let entry {
                Button { select(key) } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            EntryIcon(entry: entry, size: width).frame(height: width * 1.1).clipShape(Hexagon())
                            Hexagon().stroke((comp.carry_units ?? []).contains(key) ? hexaGold : .white.opacity(0.3), lineWidth: 1.5)
                            if isNew { Image(systemName: "plus.circle.fill").font(.system(size: 11)).foregroundStyle(.mint).background(hexaNavy, in: Circle()).offset(x: 2, y: -2) }
                        }.frame(height: width * 1.1)
                        Text(entry.name).font(.system(size: 8, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                        MicroItems(loadout: comp.loadout(for: key, on: board), width: width)
                    }.frame(width: width)
                }.buttonStyle(.plain).accessibilityIdentifier("board-unit-" + key)
                    .accessibilityLabel("\(entry.name), voir les objets")
            } else {
                Hexagon().fill(.white.opacity(0.035)).overlay(Hexagon().stroke(.white.opacity(0.1))).frame(width: width, height: width * 1.1)
                Color.clear.frame(width: width, height: 25)
            }
        }.frame(width: width, height: 78, alignment: .top)
    }
}
struct MicroItems: View {
    @EnvironmentObject private var store: Store
    let loadout: ChampionLoadout
    let width: CGFloat
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { index in
                if loadout.items.indices.contains(index), let item = store.reference?.entries.first(where: { $0.id == "item:" + loadout.items[index] }) {
                    EntryIcon(entry: item, size: (width - 2) / 3)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(hexaGold.opacity(loadout.isProjected ? 0.8 : 0), style: StrokeStyle(lineWidth: 1, dash: [2, 1])))
                } else { RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.055)).frame(width: (width - 2)/3, height: (width - 2)/3) }
            }
        }.frame(height: (width - 2)/3)
    }
}
struct BoardComparison: View {
    let previous: GuideBoard
    let current: GuideBoard
    var body: some View {
        Panel {
            Label("Ce qui change sur le plateau", systemImage: "arrow.triangle.swap").font(.headline)
            let added = current.units.filter { !previous.keys.contains($0.name) }
            let removed = previous.units.filter { !current.keys.contains($0.name) }
            if !added.isEmpty { Text("+ Entrent dans cet exemple").font(.caption.bold()).foregroundStyle(.mint); UnitStrip(units: added) }
            if !removed.isEmpty { Text("− Sortent de cet exemple").font(.caption.bold()).foregroundStyle(.orange); UnitStrip(units: removed) }
            Text("Comparaison de deux plateaux observés indépendamment, pour visualiser les différences.").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
struct EquipmentRoster: View {
    @EnvironmentObject private var store: Store
    let comp: MetaComp
    @State private var selected: SelectedGuideUnit?
    private var units: [MetaUnit] { comp.units.filter { !($0.items ?? []).isEmpty }.sorted { (comp.carry_units ?? []).contains($0.name) && !(comp.carry_units ?? []).contains($1.name) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Équiper chaque champion", systemImage: "shield.lefthalf.filled").font(.title2.bold())
            Text("Les trios du plateau final. Touche un porteur pour voir les effets, les recettes et les alternatives.").font(.subheadline).foregroundStyle(.secondary)
            ForEach(units) { unit in
                Button { selected = SelectedGuideUnit(id: unit.name) } label: {
                    Panel {
                        HStack(spacing: 12) {
                            if let entry = store.champion("champion:" + unit.name) { EntryIcon(entry: entry, size: 58) }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(store.champion("champion:" + unit.name)?.name ?? unit.name).font(.headline)
                                Text((comp.carry_units ?? []).contains(unit.name) ? "Carry · équipement cible" : "Porteur · équipement cible").font(.caption).foregroundStyle(hexaGold)
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(hexaGold)
                        }
                        ItemIcons(keys: unit.items ?? [], size: 38)
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("equipment-unit-" + unit.name)
            }
        }.sheet(item: $selected) { selection in NavigationStack { ChampionEquipmentView(comp: comp, unitKey: selection.id, board: comp.finalBoard) } }
    }
}
struct ItemIcons: View {
    @EnvironmentObject private var store: Store
    let keys: [String]
    var size: CGFloat = 36
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                if let item = store.reference?.entries.first(where: { $0.id == "item:" + key }) {
                    VStack(spacing: 5) { EntryIcon(entry: item, size: size); Text(item.name).font(.system(size: 10)).multilineTextAlignment(.center).lineLimit(3) }.frame(maxWidth: .infinity)
                }
            }
        }
    }
}
struct ChampionEquipmentView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let comp: MetaComp
    let unitKey: String
    let board: GuideBoard
    @State private var alternate: Int?
    private var champion: ReferenceEntry { store.champion("champion:" + unitKey) ?? ReferenceEntry.boardEntity(unitKey) }
    private var plan: ChampionLoadout { comp.loadout(for: unitKey, on: board) }
    private var alternatives: [MetaUnitStats.Trio] { comp.alternativeTrios(for: plan.target, excluding: plan.items) }
    private var items: [String] { if let alternate, alternatives.indices.contains(alternate) { return alternatives[alternate].item_api_names }; return plan.items }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    EntryIcon(entry: champion, size: 74)
                    VStack(alignment: .leading, spacing: 7) { Text(champion.name).font(.title.bold()).accessibilityIdentifier("equipment-champion-title"); Text(champion.kind == "champion" ? "\(champion.cost) PO · Set \(champion.set)" : "Invocation").font(.caption).foregroundStyle(.secondary) }
                }
                if plan.isProjected {
                    Label(plan.target == unitKey ? "Équipement cible du plateau final" : "Porteur temporaire d’objets", systemImage: "circle.dashed").font(.headline).foregroundStyle(hexaGold)
                    if plan.target != unitKey { TransferPortraits(from: unitKey, to: plan.target) }
                    Text("Ces objets sont un objectif du guide ; ils ne sont pas observés sur ce champion dans l’exemple sélectionné.").font(.caption).foregroundStyle(.secondary)
                } else { Badge(text: "TRIO OBSERVÉ", color: hexaGold) }
                if items.isEmpty {
                    Text("Aucun équipement n’est fourni pour ce porteur à cette étape. Les autres porteurs du plateau final sont détaillés dans la fiche de composition.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ItemIcons(keys: items, size: 48)
                    Text(alternate == nil ? "Le trio de référence" : "Alternative observée").font(.headline)
                    Text("Les trois objets sont présentés comme un ensemble. La source ne précise pas d’ordre de fabrication.").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(items.enumerated()), id: \.offset) { index, key in
                        if let item = store.reference?.entries.first(where: { $0.id == "item:" + key }) { EquipmentRecipeCard(item: item, slot: index + 1) }
                    }
                }
                if !alternatives.isEmpty { alternativesSection }
                if !champion.effectText.isEmpty { Panel { Text("La compétence de \(champion.name)").font(.headline); Text(champion.effectText).font(.subheadline).foregroundStyle(.secondary) } }
                transfersSection
            }.padding()
        }.background(hexaNavy).navigationTitle("Objets du champion").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
    }
    private var alternativesSection: some View {
        Panel {
            Label("Autres trios observés", systemImage: "arrow.triangle.swap").font(.headline)
            Button("Revenir au trio de référence") { alternate = nil }.buttonStyle(.bordered).disabled(alternate == nil)
            ForEach(Array(alternatives.enumerated()), id: \.offset) { index, trio in
                Button { alternate = index } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Alternative \(index+1)").font(.subheadline.bold()); Spacer(); if alternate == index { Image(systemName: "checkmark.circle.fill") } }
                        ItemIcons(keys: trio.item_api_names, size: 32)
                        HStack {
                            if let count = trio.nb_boards { Text("\(count.formatted()) plateaux") }
                            if let average = trio.avg_placement { Text("Moyenne \(String(format: "%.2f",average))") }
                        }.font(.caption).foregroundStyle(.secondary)
                    }.padding(10).background(alternate == index ? hexaGold.opacity(0.12) : .white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).accessibilityIdentifier("equipment-alternative-\(index)")
            }
            Text("Les résultats des trios portent sur des échantillons différents ; ils ne prouvent pas qu’une alternative est meilleure.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var transfersSection: some View {
        let holders = (comp.carry_item_holders ?? []).filter { $0.end_game_carry_api_name == unitKey }
        return Group {
            if !holders.isEmpty {
                Panel {
                    Label("Avant ce carry : porteurs temporaires", systemImage: "arrow.right.arrow.left").font(.headline)
                    ForEach(Array(holders.enumerated()), id: \.offset) { _, holder in
                        ForEach(Array(holder.stats.prefix(3).enumerated()), id: \.offset) { _, candidate in TransferPortraits(from: candidate.early_game_carry_api_name, to: unitKey) }
                    }
                    Text("Associations de porteurs observées par la source. Vérifie ton remplacement avant de vendre le porteur temporaire pour récupérer ses objets.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
struct EquipmentRecipeCard: View {
    let item: ReferenceEntry
    var slot: Int? = nil
    var body: some View {
        Panel {
            HStack(spacing: 12) {
                EntryIcon(entry: item, size: 46)
                VStack(alignment: .leading, spacing: 4) {
                    if let slot { Text("EMPLACEMENT \(slot)").font(.caption2.bold()).foregroundStyle(hexaGold) }
                    Text(item.name).font(.headline)
                    if let category = item.itemCategory { Text(category).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Text(item.effectText.isEmpty ? "La source ne fournit pas d’effet détaillé." : item.effectText).font(.subheadline)
            RecipeRow(item: item)
        }.accessibilityIdentifier("equipment-recipe-" + item.id)
    }
}
struct RecipeRow: View {
    @EnvironmentObject private var store: Store
    let item: ReferenceEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fabriquer cet objet").font(.caption.bold()).foregroundStyle(hexaGold)
            if let components = item.components, !components.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    ForEach(Array(components.enumerated()), id: \.offset) { index, key in
                        if index > 0 { Text("+").foregroundStyle(hexaGold) }
                        if let component = store.reference?.entries.first(where: { $0.id == "item:" + key }) {
                            NavigationLink { ItemDetailView(item: component) } label: {
                                VStack(spacing: 4) { EntryIcon(entry: component, size: 32); Text(component.name).font(.system(size: 10)).multilineTextAlignment(.center) }.frame(maxWidth: .infinity)
                            }.buttonStyle(.plain)
                        }
                    }
                    Image(systemName: "arrow.right").foregroundStyle(hexaGold)
                    EntryIcon(entry: item, size: 36)
                }.padding(12).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            } else { Text("Pas de recette de combinaison fournie pour cet objet.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
struct ItemDetailView: View {
    let item: ReferenceEntry
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) { EquipmentRecipeCard(item: item) }.padding() }
            .background(hexaNavy).navigationTitle("Équipement").navigationBarTitleDisplayMode(.inline)
    }
}
struct TransferPortraits: View {
    @EnvironmentObject private var store: Store
    let from: String
    let to: String
    var body: some View {
        HStack(spacing: 14) {
            portrait(from); Image(systemName: "arrow.right").foregroundStyle(hexaGold); portrait(to)
        }.frame(maxWidth: .infinity)
    }
    private func portrait(_ key: String) -> some View {
        let entry = store.champion("champion:" + key) ?? ReferenceEntry.boardEntity(key)
        return VStack(spacing: 5) { EntryIcon(entry: entry, size: 44); Text(entry.name).font(.caption).multilineTextAlignment(.center) }.frame(maxWidth: .infinity)
    }
}
