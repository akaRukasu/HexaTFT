import Foundation

struct PatchSnapshot: Codable, Identifiable {
    let pack: MetaPack
    let reference: ReferenceData?
    var provider: String? = nil
    var id: String { "\(pack.set ?? "?")-\(pack.patch ?? reference?.version ?? "?")" }
    var sourceName: String { provider ?? "Blitz" }
}

struct PatchSelection: Codable, Hashable {
    enum Channel: String, Codable, CaseIterable, Identifiable {
        case live = "LIVE EUW", pbe = "PBE", archives = "Archives"
        var id: String { rawValue }
    }
    var channel: Channel = .live
    var archiveID: String?
}

struct UltimateContext: Codable {
    let liveBuild: String
    let pbeBuild: String
    let pbeObservedAt: String
    let euwAssetVersion: String
}

struct ReferenceChange: Identifiable {
    let id: String
    let old: ReferenceEntry?
    let new: ReferenceEntry?
    var name: String { new?.name ?? old?.name ?? id }
    var kind: String { new?.kind ?? old?.kind ?? "" }
    var changedStats: [String] {
        let before = old?.balance ?? [:], after = new?.balance ?? [:]
        return Set(before.keys).union(after.keys).filter { before[$0] != after[$0] }.sorted()
    }
    var status: String { old == nil ? "Ajout" : new == nil ? "Retrait" : "Modification" }
    static func compare(_ before: ReferenceData, _ after: ReferenceData) -> [Self] {
        let left = Dictionary(before.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let right = Dictionary(after.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return Set(left.keys).union(right.keys).compactMap { id in
            let old = left[id], new = right[id]
            if let old, let new, old.name == new.name, old.cost == new.cost,
               old.description == new.description, old.components == new.components, old.balance == new.balance { return nil }
            return Self(id: id, old: old, new: new)
        }.sorted { ($0.kind, $0.name, $0.id) < ($1.kind, $1.name, $1.id) }
    }
}


struct PartnerGuide: Codable, Identifiable {
    let id: String
    let title: String
    let style: String
    let core: [String]
    let plan: String
    let source: URL
    let provider: String
}
struct ExperimentalGuides: Codable {
    let revision: String
    let set: String
    let retrievedAt: String
    let guides: [PartnerGuide]
}
struct PartnerFeed: Codable {
    let live: PatchSnapshot?
    let pbe: ExperimentalGuides?
}
