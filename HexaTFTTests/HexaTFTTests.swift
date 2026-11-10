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
            for level in comp.variations?.levels?.keys.map({ $0 }) ?? [] {
                for board in comp.guideBoards(level: level) {
                    XCTAssertTrue(board.positions.isEmpty || Set(board.positions.map(\.unit_api_name)) == board.keys)
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

    @MainActor func testPatchSelectionIsPersistedAndDoesNotShareCatalogues() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let meta = MetaStore(directory: directory)
        let live = try XCTUnwrap(meta.pack)
        XCTAssertEqual(live.patch, "18.6")
        XCTAssertTrue(live.data.isEmpty)
        let liveCodex = try XCTUnwrap(meta.reference?.version)
        meta.select(.pbe)
        XCTAssertTrue(meta.comps.isEmpty)
        XCTAssertNotEqual(meta.reference?.version, liveCodex)
        XCTAssertEqual(MetaStore(directory: directory).selection.channel, .pbe)
        meta.select(.archives)
        XCTAssertEqual(meta.pack?.patch, "18.5")
        XCTAssertTrue(meta.comps.allSatisfy { $0.display_patch == "16.21" })
        XCTAssertNotEqual(meta.reference?.version, liveCodex)
    }

    func testPatchDiffDoesNotConfuseCostAndStatsWithIdentity() {
        let before = ReferenceEntry(id: "champion:fixture", name: "Test", kind: "champion", set: "18", cost: 3,
            description: "", imageURL: "", balance: ["mana": 40, "hp": 600])
        let after = ReferenceEntry(id: "champion:fixture", name: "Test", kind: "champion", set: "18", cost: 3,
            description: "", imageURL: "", balance: ["mana": 50, "hp": 600])
        let left = ReferenceData(version: "live", source: "", retrievedAt: "", entries: [before])
        let right = ReferenceData(version: "pbe", source: "", retrievedAt: "", entries: [after])
        let diff = ReferenceChange.compare(left, right)
        XCTAssertEqual(diff.count, 1)
        XCTAssertEqual(diff.first?.changedStats, ["mana"])
        XCTAssertTrue(ReferenceChange.compare(left, left).isEmpty)
    }

    func testRiotNewsOnlyListsSupportedArticlePaths() {
        let html = #"<a aria-label="Couronne &amp; finales" href="/en-us/news/esports/crown"><a aria-label="Double" href="/en-us/news/esports/crown/"><a aria-label="Hors site" href="https://example.com/en-us/news/esports/foo"><a aria-label="Patch" href="/en-us/news/game-updates/patch">"#
        let esports = RiotNewsStore.parse(html, topic: "esports")
        XCTAssertEqual(esports.map(\.title), ["Couronne & finales"])
        XCTAssertEqual(RiotNewsStore.parse(html, topic: "game-updates").map(\.title), ["Patch"])
    }

    func testTrackerComputesMetricsFromCompletedPlacements() {
        let matches = [1, 4, 8].enumerated().map { offset, placement in
            TrackedMatch(id: String(offset), timestamp: 0, patch: nil, set: 18, queue: 1100,
                mode: nil, placement: placement, level: nil, units: [], traits: [], augments: [], lobby: [])
        }
        let summary = MatchSummary(matches)
        XCTAssertEqual(summary.count, 3)
        XCTAssertEqual(summary.average, 13.0 / 3)
        XCTAssertEqual(summary.top4, 2.0 / 3)
        XCTAssertEqual(summary.wins, 1.0 / 3)
        XCTAssertNil(MatchSummary([]).average)
    }
    @MainActor func testCurrentHexaGuidesHaveValidStagesAndEquipmentWithoutInventedStats() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let meta = MetaStore(directory: directory)
        XCTAssertEqual(meta.editorialComps.count, 18)
        let reference = try XCTUnwrap(meta.reference)
        for comp in meta.editorialComps {
            XCTAssertNil(comp.stats)
            XCTAssertNil(comp.finalBoard.sample)
            XCTAssertEqual(Set(comp.finalBoard.positions.map(\.unit_api_name)), comp.finalBoard.keys)
            for stage in Stage.allCases {
                let board = try XCTUnwrap(comp.guideBoards(stage: stage).first)
                XCTAssertFalse(board.positions.isEmpty)
                XCTAssertEqual(Set(board.positions.map(\.board_position)).count, board.positions.count)
                XCTAssertNotNil(comp.authored?.stages[stage.rawValue])
            }
            for key in comp.units.flatMap({ $0.items ?? [] }) {
                let item = try XCTUnwrap(reference.entries.first { $0.id == "item:" + key })
                XCTAssertFalse(item.effectText.isEmpty, item.name)
                XCTAssertEqual(item.components?.count, 2, item.name)
            }
        }
        meta.select(.pbe)
        XCTAssertGreaterThan(meta.editorialComps.count, 12)
        for comp in meta.editorialComps {
            XCTAssertNil(comp.stats)
            XCTAssertFalse(comp.finalBoard.positions.isEmpty)
            XCTAssertEqual(Set(comp.finalBoard.positions.map(\.board_position)).count, comp.finalBoard.positions.count)
            XCTAssertTrue(LiveGuideCatalogue.isCompatible(comp, with: try XCTUnwrap(meta.reference)))
        }
        try? FileManager.default.removeItem(at: directory)
    }

    @MainActor func testBundledRadarOpensNativeGuidesAndKeepsTheMatchingCodex() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let meta = MetaStore(directory: directory)
        let radar = MetaRadarSnapshot.bundled
        let catalogue = try XCTUnwrap(meta.catalogue(for: radar))
        let reference = try XCTUnwrap(catalogue.reference)
        meta.select(.archives)
        XCTAssertNotEqual(meta.reference?.version, reference.version)
        for entry in radar.readings {
            let guide = try XCTUnwrap(meta.nativeGuide(for: entry, in: radar, catalogue: catalogue), entry.title)
            XCTAssertTrue(Set(entry.champions).isSubset(of: guide.finalBoard.keys), entry.title)
            XCTAssertTrue(guide.finalBoard.positions.count >= 7, entry.title)
            XCTAssertTrue(guide.finalBoard.units.contains { $0.items?.count == 3 }, entry.title)
            let core = entry.coreBoard(reference: reference)
            XCTAssertEqual(core.keys, Set(entry.champions))
            XCTAssertEqual(Set(core.positions.map(\.board_position)).count, entry.champions.count)
            XCTAssertTrue(core.units.allSatisfy { $0.items == nil })
        }
        let nextPatch = MetaRadarSnapshot(patch: "18.7", build: "16.23", set: "18",
                                         retrievedAt: Date(), readings: radar.readings)
        XCTAssertNil(meta.catalogue(for: nextPatch))
        XCTAssertNil(meta.nativeGuide(for: radar.readings[0], in: nextPatch, catalogue: catalogue))
    }

    func testPublicRiotProfileUsesSeparateEscapedNameAndTag() throws {
        let identity = try XCTUnwrap(RiotIdentity("Tactikk # EUW", region: "euw1"))
        XCTAssertEqual(identity.riotID, "Tactikk#EUW")
        XCTAssertEqual(identity.publicProfile?.absoluteString, "https://tactics.tools/player/euw/Tactikk/EUW")
        XCTAssertEqual(RiotIdentity("Nom Avec Espace#EUW", region: "euw1")?.publicProfile?.absoluteString,
                       "https://tactics.tools/player/euw/Nom%20Avec%20Espace/EUW")
        XCTAssertNil(RiotIdentity("Tactikk", region: "euw1"))
        XCTAssertNil(RiotIdentity("Tactikk#EUW", region: "invalid"))
    }

    func testNativePatchParserKeepsNumericChangesAndTheirNestedSubject() throws {
        let html = #"<h2>Équilibrage</h2><h4>Champions</h4><ul><li><strong>Nidalee</strong><ul><li><strong>Forme puissance</strong><ul><li>Attaques&nbsp;: 185/275 <span>⇒</span> 195/295</li></ul></li></ul></li><li>Un correctif de texte</li></ul>"#
        let note = try XCTUnwrap(RiotPatchParser.parse(html, patch: "18.7"))
        let change = try XCTUnwrap(note.groups.first?.changes.first)
        XCTAssertEqual(note.groups.first?.name, "Équilibrage · Champions")
        XCTAssertEqual(change.title, "Nidalee · Forme puissance")
        XCTAssertEqual(change.detail, "Attaques")
        XCTAssertEqual(change.before, "185/275")
        XCTAssertEqual(change.after, "195/295")
        XCTAssertEqual(note.groups.first?.changes.count, 1)
        XCTAssertEqual(RiotArticle(title: "", path: "/en-us/news/game-updates/teamfight-tactics-patch-18-7/").patchNumber, "18.7")
    }

    @MainActor func testPartnerRadarRejectsUnmatchedBuildAndMissingSourceContext() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let meta = MetaStore(directory: directory)
        let reference = try XCTUnwrap(meta.live?.reference)
        var reading = try XCTUnwrap(MetaRadarSnapshot.bundled.readings.first)
        let withoutContext = MetaRadarSnapshot(patch: "18.6", build: "16.22", set: "18", retrievedAt: Date(), readings: [reading])
        XCTAssertFalse(withoutContext.isValid(for: reference, patch: "18.6"))
        reading.scope = "Diamant+ · 5–10 novembre"
        let valid = MetaRadarSnapshot(patch: "18.6", build: "16.22", set: "18", retrievedAt: Date(), readings: [reading])
        XCTAssertTrue(valid.isValid(for: reference, patch: "18.6"))
        XCTAssertFalse(valid.isValid(for: reference, patch: "18.7"))
        let wrongBuild = MetaRadarSnapshot(patch: "18.6", build: "16.23", set: "18", retrievedAt: Date(), readings: [reading])
        XCTAssertFalse(wrongBuild.isValid(for: reference, patch: "18.6"))
    }

    @MainActor func testTrackerCachesAuthorizedProfileAndRejectsOtherAccount() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let tracker = TrackerStore(service: nil, directory: directory)
        let identity = try XCTUnwrap(RiotIdentity("Fixture#EUW", region: "euw1"))
        try tracker.saveProfile(identity)
        let match = TrackedMatch(id: "EUW1_fixture", timestamp: 100, patch: "16.22.1", set: 18, queue: 1100,
                                 mode: nil, placement: 2, level: 8, units: [], traits: [], augments: [], lobby: [])
        let rank = RiotProfile.Rank(queue: "RANKED_TFT", tier: "GOLD", division: "I", lp: 42, wins: 10, losses: 8)
        let profile = RiotProfile(id: "fixture", riotID: "Fixture#EUW", region: "euw1", observedAt: 200, matches: [match], ranks: [rank])
        try tracker.ingest(profile, for: identity)
        XCTAssertEqual(tracker.profile?.matches.first?.placement, 2)
        XCTAssertEqual(TrackerStore(service: nil, directory: directory).points.first?.rank.lp, 42)
        let wrong = RiotProfile(id: "other", riotID: "Other#EUW", region: "euw1", observedAt: 300, matches: [], ranks: [])
        XCTAssertThrowsError(try tracker.ingest(wrong, for: identity))
        XCTAssertEqual(tracker.profile?.riotID, identity.riotID)
    }

    func testMetaSortRanksTop4AndDiscoveryRotatesSources() {
        let entries = MetaRadarSnapshot.bundled.readings
        let ranked = MetaSort.top4.readings(entries)
        XCTAssertEqual(ranked.map(\.top4), entries.map(\.top4).sorted(by: >))
        let discovery = MetaSort.discovery.readings(entries)
        XCTAssertEqual(Set(discovery.prefix(3).map(\.provider)).count, 3)
        XCTAssertEqual(Set(discovery.map(\.id)), Set(entries.map(\.id)))
        let wins = MetaSort.top1.readings(entries)
        XCTAssertNil(wins.last?.top1)
    }

    func testRadarPagingDeduplicatesAndRejectsAnotherSnapshot() throws {
        let original = MetaRadarSnapshot.bundled
        let first = MetaRadarSnapshot(patch: original.patch, build: original.build, set: original.set,
                                      retrievedAt: original.retrievedAt, readings: Array(original.readings.prefix(2)), nextCursor: "page-2")
        let second = MetaRadarSnapshot(patch: original.patch, build: original.build, set: original.set,
                                       retrievedAt: original.retrievedAt, readings: Array(original.readings.dropFirst().prefix(2)))
        let merged = try XCTUnwrap(first.merging(second, after: "page-2"))
        XCTAssertEqual(merged.readings.map(\.id), original.readings.prefix(3).map(\.id))
        XCTAssertNil(merged.nextCursor)
        XCTAssertNil(first.merging(second, after: "wrong-cursor"))
        let wrong = MetaRadarSnapshot(patch: "18.7", build: original.build, set: original.set,
                                      retrievedAt: original.retrievedAt, readings: second.readings)
        XCTAssertNil(first.merging(wrong, after: "page-2"))
    }
}
