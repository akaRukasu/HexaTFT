import XCTest
@testable import HexaTFT

final class HexaTFTTests: XCTestCase {
    private func pack() -> Data {
        let phases = Stage.allCases.map { Phase(stage: $0, level: "6", economy: "RepÃ¨re", objective: "Comparer", options: []) }
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

    func testBundledMetaAndFrenchReferenceMatch() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "meta", withExtension: "json"))
        let pack = try MetaPack.decode(Data(contentsOf: url))
        XCTAssertGreaterThan(pack.data.count, 10)
        let referenceURL = try XCTUnwrap(Bundle.main.url(forResource: "reference", withExtension: "json"))
        let reference = try JSONDecoder().decode(ReferenceData.self, from: Data(contentsOf: referenceURL))
        let ids = Set(reference.entries.map(\.id))
        XCTAssertEqual(Set(reference.entries.map(\.set)).count, 1)
        for comp in pack.data {
            for unit in comp.units {
                XCTAssertTrue(ids.contains("champion:" + unit.name), unit.name)
                for item in unit.items ?? [] { XCTAssertTrue(ids.contains("item:" + item), item) }
            }
        }
        XCTAssertThrowsError(try MetaPack.decode(Data("{\"data\":[]}".utf8)))
        XCTAssertThrowsError(try MetaPack.decode(Data(repeating: 0, count: 20_000_001)))
    }
    @MainActor func testMetaPinAndBoardCopyPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = Store(directory: directory)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "meta", withExtension: "json"))
        let comp = try XCTUnwrap(MetaPack.decode(Data(contentsOf: url)).data.first)
        store.pinMeta(comp)
        store.copyBoard(comp.units_positions ?? [])
        let restored = Store(directory: directory)
        XCTAssertEqual(restored.state.pinnedID, comp.id)
        XCTAssertEqual(restored.state.pinnedName, comp.title(store.reference))
        XCTAssertEqual(restored.state.board.count, comp.units_positions?.count)
        XCTAssertFalse(restored.state.board.isEmpty)
    }

    func testVisualGuideUsesExactObservedPositionsAndNeverEmptyStages() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "meta", withExtension: "json"))
        let pack = try MetaPack.decode(Data(contentsOf: url))
        for comp in pack.data {
            for stage in Stage.allCases {
                let boards = comp.guideBoards(stage: stage)
                XCTAssertFalse(boards.isEmpty)
                for board in boards {
                    XCTAssertFalse(board.units.isEmpty)
                    XCTAssertTrue(board.positions.allSatisfy { board.keys.contains($0.unit_api_name) })
                    XCTAssertEqual(Set(board.positions.map(\.board_position)).count, board.positions.count)
                }
            }
            let unmapped = MetaVariant(units: [MetaUnit(name: "missing-test-unit", items: nil, star_level: nil)], units_positions: nil, nb_boards: 1, avg_placement: nil)
            XCTAssertTrue(comp.board(from: unmapped, label: "Test").positions.isEmpty)
            if comp.variations?.stages?["6"]?.allSatisfy({ $0.units.isEmpty }) == true {
                XCTAssertTrue(try XCTUnwrap(comp.guideBoards(stage: .end).first).isFinal)
            }
        }
    }
    func testProjectedItemsAndRecipesRemainDistinctFromObservedItems() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "meta", withExtension: "json"))
        let comp = try XCTUnwrap(MetaPack.decode(Data(contentsOf: url)).data.first)
        let unit = try XCTUnwrap(comp.units.first { !($0.items ?? []).isEmpty })
        let actual = comp.loadout(for: unit.name, on: comp.finalBoard)
        XCTAssertFalse(actual.isProjected)
        XCTAssertEqual(actual.items, unit.items)
        let early = GuideBoard(units: [MetaUnit(name: unit.name, items: nil, star_level: nil)], positions: [], sourceLabel: "Test", sample: nil, isFinal: false)
        let planned = comp.loadout(for: unit.name, on: early)
        XCTAssertTrue(planned.isProjected)
        XCTAssertEqual(planned.items, actual.items)
        let referenceURL = try XCTUnwrap(Bundle.main.url(forResource: "reference", withExtension: "json"))
        let reference = try JSONDecoder().decode(ReferenceData.self, from: Data(contentsOf: referenceURL))
        let ids = Set(reference.entries.map(\.id))
        for item in reference.entries where item.kind == "item" {
            for component in item.components ?? [] { XCTAssertTrue(ids.contains("item:" + component), component) }
        }
        XCTAssertGreaterThan(reference.entries.filter { !($0.components ?? []).isEmpty }.count, 50)
        let legacy = Data("{\"id\":\"item:test\",\"name\":\"Test\",\"kind\":\"item\",\"set\":\"18\",\"cost\":0,\"description\":\"Effet\",\"imageURL\":\"\"}".utf8)
        XCTAssertNil(try JSONDecoder().decode(ReferenceEntry.self, from: legacy).components)
    }
}
