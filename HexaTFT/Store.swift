import Foundation
import Combine

@MainActor final class Store: ObservableObject {
    @Published private(set) var catalogue: Catalogue?
    @Published private(set) var reference: ReferenceData?
    private var workshopReference: ReferenceData?
    @Published private(set) var state = SavedState()
    @Published var error: String?
    private let directory: URL

    init(directory: URL? = nil, loadBundledData: Bool = true) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("HexaTFT")
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            let stateURL = self.directory.appendingPathComponent("state.json")
            if FileManager.default.fileExists(atPath: stateURL.path) {
                state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: stateURL))
                guard state.matches.allSatisfy({ (1...8).contains($0.placement) }),
                      state.board.keys.allSatisfy({ (0..<28).contains($0) }) else {
                    throw DataIssue.invalid("La sauvegarde locale est invalide.")
                }
            }
        } catch { self.error = "Lecture de la sauvegarde : \(error.localizedDescription)"; state = SavedState() }
        guard loadBundledData else { return }
        do {
            if let url = Bundle.main.url(forResource: "catalogue", withExtension: "json") {
                catalogue = try Catalogue.decode(Data(contentsOf: url))
            }
            let imported = self.directory.appendingPathComponent("catalogue.json")
            if FileManager.default.fileExists(atPath: imported.path) {
                catalogue = try Catalogue.decode(Data(contentsOf: imported))
            }
        } catch { self.error = "Catalogue : \(error.localizedDescription)" }
        do {
            if let url = Bundle.main.url(forResource: "reference", withExtension: "json") {
                reference = try JSONDecoder().decode(ReferenceData.self, from: Data(contentsOf: url))
                workshopReference = reference
            }
        } catch { self.error = "Encyclopédie : \(error.localizedDescription)" }
    }

    func showReference(_ value: ReferenceData?) { reference = value }
    var workshopChampions: [ReferenceEntry] { workshopReference?.entries.filter { $0.kind == "champion" } ?? [] }
    func boardChampion(_ id: String) -> ReferenceEntry? { workshopChampions.first { $0.id == id } }
    var guides: [Guide] { catalogue?.guides ?? [] }
    var pinned: Guide? { guides.first { $0.id == state.pinnedID } }
    var champions: [ReferenceEntry] { reference?.entries.filter { $0.kind == "champion" } ?? [] }
    var top4Rate: Double? {
        guard !state.matches.isEmpty else { return nil }
        return Double(state.matches.filter { $0.placement <= 4 }.count) / Double(state.matches.count)
    }
    func champion(_ id: String) -> ReferenceEntry? { champions.first { $0.id == id } }

    private func commit(_ value: SavedState) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: directory.appendingPathComponent("state.json"), options: .atomic)
            state = value
        } catch { self.error = "Sauvegarde impossible : \(error.localizedDescription)" }
    }
    func pin(_ guide: Guide) { var next = state; next.pinnedID = guide.id; next.pinnedName = guide.name; commit(next) }
    func pinMeta(_ comp: MetaComp, reference guideReference: ReferenceData? = nil) {
        var next = state
        if comp.publishedPlan != nil, next.pinnedID != comp.id { next.stage = .opening }
        next.pinnedID = comp.id
        next.pinnedName = comp.title(guideReference ?? reference)
        commit(next)
    }
    func copyBoard(_ positions: [MetaPosition]) {
        var next = state; next.board = [:]
        for position in positions where (0..<28).contains(position.board_position) {
            let id = "champion:" + position.unit_api_name
            if boardChampion(id) != nil { next.board[position.board_position] = id }
        }
        commit(next)
    }
    func setStage(_ stage: Stage) { var next = state; next.stage = stage; commit(next) }
    func favorite(_ id: String) {
        var next = state
        if next.favorites.contains(id) { next.favorites.remove(id) } else { next.favorites.insert(id) }
        commit(next)
    }
    func place(_ entry: ReferenceEntry?, at index: Int) {
        guard (0..<28).contains(index), entry == nil || entry?.kind == "champion" else { return }
        var next = state; next.board[index] = entry?.id; commit(next)
    }
    func clearBoard() { var next = state; next.board = [:]; commit(next) }
    func addMatch(placement: Int, notes: String) {
        guard (1...8).contains(placement), notes.count <= 4_000 else { return }
        var next = state
        next.matches.insert(MatchNote(placement: placement, guideName: pinned?.name ?? state.pinnedName ?? "Plan libre",
                                      patch: catalogue?.patch ?? "Inconnu", notes: notes), at: 0)
        commit(next)
    }
    func deleteMatches(at offsets: IndexSet) {
        var next = state
        for index in offsets.sorted(by: >) where next.matches.indices.contains(index) { next.matches.remove(at: index) }
        commit(next)
    }
    func importCatalogue(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 2_000_000 else { throw DataIssue.invalid("Catalogue limité à 2 Mo.") }
            let data = try Data(contentsOf: url)
            let next = try Catalogue.decode(data)
            try data.write(to: directory.appendingPathComponent("catalogue.json"), options: .atomic)
            catalogue = next
        } catch { self.error = "Import refusé : \(error.localizedDescription)" }
    }

    var boardText: String {
        (["Hexa — plateau personnel (pas une recommandation méta)"] + state.board.keys.sorted().map {
            "Ligne \($0 / 7 + 1), case \($0 % 7 + 1) : \(boardChampion(state.board[$0] ?? "")?.name ?? "?")"
        }).joined(separator: "\n")
    }
}
