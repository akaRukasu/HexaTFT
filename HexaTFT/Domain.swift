import Foundation

enum Stage: String, CaseIterable, Codable, Identifiable, Hashable {
    case opening = "2-1", early = "2-5", mid = "3-2", transition = "4-1", late = "5-1", end = "6-1"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .opening: return "Ouverture"
        case .early: return "Première transition"
        case .mid: return "Milieu de partie"
        case .transition: return "Stabilisation"
        case .late: return "Fin de partie"
        case .end: return "Derniers combats"
        }
    }
}

struct Phase: Codable, Identifiable {
    let stage: Stage
    let level: String
    let economy: String
    let objective: String
    let options: [String]
    var id: String { stage.rawValue }
}

struct Guide: Codable, Identifiable {
    let id: String
    let name: String
    let style: String
    let difficulty: String
    let summary: String
    let tags: [String]
    let itemNotes: [String]
    let positioning: [String]
    let phases: [Phase]
    // A guide is authored before play, never recalculated from a live board.
    func phase(at stage: Stage) -> Phase? { phases.first { $0.stage == stage } }
}

struct Catalogue: Codable {
    let schemaVersion: Int
    let patch: String
    let updatedAt: String
    let source: String
    let isDemo: Bool
    let guides: [Guide]

    static func decode(_ data: Data) throws -> Catalogue {
        guard data.count <= 2_000_000 else { throw DataIssue.invalid("Catalogue limité à 2 Mo.") }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.schemaVersion == 1, !value.guides.isEmpty, value.guides.count <= 200,
              Set(value.guides.map(\.id)).count == value.guides.count,
              !value.patch.isEmpty, !value.source.isEmpty,
              value.guides.allSatisfy({ guide in
                  !guide.id.isEmpty && !guide.name.isEmpty && !guide.summary.isEmpty &&
                  guide.name.count <= 120 && guide.summary.count <= 4_000 &&
                  guide.phases.count == Stage.allCases.count &&
                  Set(guide.phases.map(\.stage)).count == Stage.allCases.count
              }) else { throw DataIssue.invalid("Format invalide : version, identifiants uniques et six étapes requis.") }
        return value
    }
}

enum DataIssue: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

struct ReferenceEntry: Codable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let set: String
    let cost: Int
    let description: String
    let imageURL: String
    var initials: String { String(name.prefix(2)).uppercased() }
}

struct ReferenceData: Codable {
    let version: String
    let source: String
    let retrievedAt: String
    let entries: [ReferenceEntry]
}

struct MatchNote: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    let placement: Int
    let guideName: String
    let patch: String
    let notes: String
}

struct SavedState: Codable {
    var pinnedID: String?
    var stage = Stage.opening
    var favorites: Set<String> = []
    var board: [Int: String] = [:]
    var matches: [MatchNote] = []
}
