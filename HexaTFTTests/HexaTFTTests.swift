import XCTest
@testable import HexaTFT

final class HexaTFTTests: XCTestCase {
    private func pack() -> Data {
        let phases = Stage.allCases.map { Phase(stage: $0, level: "6", economy: "Repère", objective: "Comparer", options: []) }
        let guide = Guide(id: "example", name: "Test", style: "Reroll", difficulty: "Accessible", summary: "Guide de test",
                          tags: [], itemNotes: [], positioning: [], phases: phases)
        return try! JSONEncoder().encode(Catalogue(schemaVersion: 1, patch: "test", updatedAt: "2026-11-03",
                                                  source: "XCTest", isDemo: true, guides: [guide]))
    }

    func testCatalogueRejectsDuplicateStagesAndTruncation() throws {
        let valid = try Catalogue.decode(pack())
        XCTAssertEqual(valid.guides[0].phases.count, 6)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: pack()) as? [String: Any])
        var guides = try XCTUnwrap(json["guides"] as? [[String: Any]])
        var phases = try XCTUnwrap(guides[0]["phases"] as? [[String: Any]])
        phases[1]["stage"] = phases[0]["stage"]
        guides[0]["phases"] = phases
        json["guides"] = guides
        XCTAssertThrowsError(try Catalogue.decode(JSONSerialization.data(withJSONObject: json)))
        XCTAssertThrowsError(try Catalogue.decode(pack().prefix(20)))
        XCTAssertThrowsError(try Catalogue.decode(Data(repeating: 32, count: 2_000_001)))
    }

    @MainActor func testImportIsTransactionalAndStateSurvivesRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = Store(directory: directory, loadBundledData: false)
        let url = directory.appendingPathComponent("input.json")
        try pack().write(to: url)
        store.importCatalogue(url)
        let guide = try XCTUnwrap(store.catalogue?.guides.first)
        store.pin(guide)
        store.setStage(.transition)
        store.addMatch(placement: 3, notes: "Objets trop tardifs")
        store.addMatch(placement: 8, notes: "Transition difficile")
        store.addMatch(placement: 0, notes: "Invalide")
        XCTAssertEqual(store.top4Rate, 0.5)
        try Data("invalide".utf8).write(to: url)
        store.importCatalogue(url)
        XCTAssertNotNil(store.error)
        XCTAssertEqual(store.catalogue?.guides.first?.id, guide.id)
        let restored = Store(directory: directory, loadBundledData: false)
        XCTAssertEqual(restored.state.pinnedID, guide.id)
        XCTAssertEqual(restored.state.stage, .transition)
        XCTAssertEqual(restored.state.matches.count, 2)
        XCTAssertEqual(restored.state.matches.first?.notes, "Transition difficile")
    }
}
