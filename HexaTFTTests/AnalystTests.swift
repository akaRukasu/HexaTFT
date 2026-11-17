import XCTest
@testable import HexaTFT

final class AnalystTests: XCTestCase {
    func testPublicAccountWithNativeNetworking() async throws {
        let identity = try XCTUnwrap(RiotIdentity("akarukasu#1703",region:"euw1"))
        let profile = try await OPGGTracker.fetch(identity)
        XCTAssertEqual(profile.riotID.lowercased(),identity.riotID.lowercased())
        XCTAssertFalse(profile.matches.isEmpty)
        XCTAssertNotNil(profile.ranks.first { $0.queue == "RANKED_TFT" })
    }
    private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
    private func sample() throws -> [TrackedMatch] { try fixture("analysis-sample", as: [TrackedMatch].self) }
    private func html(_ payload: [String: Any]) throws -> String {
        let tree: [Any] = ["$", "$L2", NSNull(), ["data": payload]]
        let line = "1:" + String(decoding: try JSONSerialization.data(withJSONObject: tree), as: UTF8.self) + "\n"
        let chunk = String(decoding: try JSONSerialization.data(withJSONObject: [1,line]),as:UTF8.self)
        return "<script>self.__next_f.push(\(chunk))</script>"
    }
    func testAnonymizedCorpusSeparatesSetsModesAndDuplicateMatches() throws {
        let matches = try sample()
        let report = MatchAnalyst(matches: matches + matches, set: 18)
        XCTAssertEqual(report.matches.count,30)
        XCTAssertEqual(report.summary.average,148.0/30,accuracy:0.00001)
        XCTAssertEqual(report.summary.top4,13)
        XCTAssertEqual(report.summary.bottoms,11)
        let previous = MatchAnalyst(matches:matches,set:17)
        XCTAssertEqual(previous.summary.average,140.0/30,accuracy:0.00001)
        XCTAssertEqual(previous.summary.top4,14)
        let last = MatchAnalyst(matches:matches,set:18,limit:10)
        XCTAssertEqual(last.summary.average,5.7,accuracy:0.00001)
        XCTAssertEqual(last.summary.top4,3)
        var duo = try JSONSerialization.jsonObject(with: JSONEncoder().encode(matches.first!)) as! [String:Any]
        duo["queue"] = 1160; duo["id"] = "duo"
        let differentMode = try JSONDecoder().decode(TrackedMatch.self,from:JSONSerialization.data(withJSONObject:duo))
        XCTAssertEqual(MatchAnalyst(matches: matches + [differentMode], set:18).summary.count,30)
        XCTAssertNil(MatchSummary([differentMode,matches.first!]).average)
    }
    func testCarryCohortsExcludeComponentsAndUnknownItems() throws {
        let report = MatchAnalyst(matches:try sample(),set:18)
        let morgana = try XCTUnwrap(report.cohorts.first { $0.id == "DA_18_Morgana" })
        XCTAssertEqual(morgana.improved.count,4)
        XCTAssertEqual(morgana.twoStar.count,4)
        XCTAssertTrue(morgana.threeStar.isEmpty)
        XCTAssertEqual(AnalysisSummary(matches:morgana.improved).average,3.25,accuracy:0.00001)
        XCTAssertEqual(AnalysisSummary(matches:morgana.improved).top4,4)
        XCTAssertEqual(morgana.oneStar.count,4)
        XCTAssertEqual(AnalysisSummary(matches:morgana.oneStar).average,6,accuracy:0.00001)
        XCTAssertFalse(MatchItem(key:"DA_Component_RecurveBow",name:"Arc",category:"core").isComplete)
        XCTAssertFalse(MatchItem(key:"future-item",name:"?",category:nil).isComplete)
        XCTAssertTrue(MatchItem(key:"DA_VoidStaff",name:"Void",category:"core").isComplete)
        let old = TrackedMatch.Unit(key:"test",stars:2,items:["unknown-1","unknown-2"])
        XCTAssertEqual(old.completeItems.count,0)
        XCTAssertEqual(old.unknownEquipment,2)
    }
    func testSmallSamplesHaveHonestIntervalsAndTraceableFindings() throws {
        let report = MatchAnalyst(matches:try sample(),set:18)
        for finding in report.findings {
            XCTAssertFalse(finding.evidence.isEmpty)
            XCTAssertTrue(finding.evidence.allSatisfy { $0.set == 18 && $0.queue == 1100 && $0.placement > 4 })
            XCTAssertFalse(finding.limitation.isEmpty)
        }
        let winners = Array(report.matches.filter { $0.placement <= 4 }.prefix(4))
        let interval = AnalysisSummary(matches:winners).interval
        XCTAssertEqual(interval.lowerBound,0.5101,accuracy:0.001)
        XCTAssertEqual(interval.upperBound,1,accuracy:0.00001)
        XCTAssertEqual(AnalysisSummary(matches:[]).interval,0...1)
        let (answer,_) = AnalystStore.answer("Analyse en direct",report:report)
        XCTAssertTrue(answer.contains("parties terminées"))
        let (objects,ids) = AnalystStore.answer("Que montrent mes objets ?",report:report)
        XCTAssertTrue(objects.contains("Limite"))
        XCTAssertTrue(ids.allSatisfy { id in report.matches.contains { $0.id == id } })
    }
    func testPublicParserPreservesEquipmentSeasonsAndUnknownAugments() throws {
        let url = try XCTUnwrap(Bundle(for:Self.self).url(forResource:"opgg-evidence",withExtension:"json"))
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any])
        let identity = try XCTUnwrap(RiotIdentity("Fixture#EUW",region:"euw1"))
        let profile = try OPGGTracker.parse(html(raw),identity:identity)
        XCTAssertEqual(profile.currentSet,18)
        XCTAssertTrue(profile.seasons?.contains { $0.number == "17" && $0.ranks.count == 2 } == true)
        XCTAssertEqual(profile.matches.first?.augmentsKnown,false)
        let equipped = profile.matches.flatMap(\.units).first { $0.completeItems.count > 0 }
        XCTAssertNotNil(equipped?.equipment?.first?.imageURL)
        XCTAssertNotNil(equipped?.cost)
        XCTAssertNotNil(equipped?.range)
        let archive = try OPGGTracker.parseArchive(html(raw),identity:identity,set:18)
        XCTAssertEqual(archive.matches.count,2)
        XCTAssertThrowsError(try OPGGTracker.parseArchive(html(raw),identity:identity,set:17))
        raw["queueType"] = "ALL"
        XCTAssertThrowsError(try OPGGTracker.parseArchive(html(raw),identity:identity,set:18))
        XCTAssertTrue(try XCTUnwrap(OPGGTracker.profileURL(identity,set:17)?.absoluteString).contains("queueType=RANKED_TFT"))
        var container = try XCTUnwrap(raw["matches"] as? [String:Any])
        var rawMatches = try XCTUnwrap(container["matches"] as? [[String:Any]])
        var units = try XCTUnwrap(rawMatches[0]["units"] as? [[String:Any]])
        units[0]["items"] = NSNull(); rawMatches[0]["units"] = units
        container["matches"] = rawMatches; raw["matches"] = container
        let incomplete = try OPGGTracker.parse(html(raw),identity:identity)
        XCTAssertNil(incomplete.matches.first?.units.first?.equipment)
    }
    @MainActor func testTrackerMergesNewMatchesDespiteOlderProfilePublicationAndArchivesPersist() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let store = TrackerStore(directory:dir)
        let identity = try XCTUnwrap(RiotIdentity("Fixture#EUW",region:"euw1"))
        try store.saveProfile(identity)
        let matches = try sample()
        let rank = RiotProfile.Rank(queue:"RANKED_TFT",tier:"GOLD",division:"III",lp:40,wins:nil,losses:nil)
        let first = RiotProfile(id:"fixture",riotID:identity.riotID,region:identity.region,observedAt:200,matches:[matches[1]],ranks:[rank])
        try store.ingest(first,for:identity)
        let older = RiotProfile(id:"fixture",riotID:identity.riotID,region:identity.region,observedAt:100,matches:[matches[0]],ranks:[])
        try store.ingest(older,for:identity)
        XCTAssertEqual(store.profile?.matches.count,2)
        XCTAssertEqual(store.profile?.ranks.first?.lp,40)
        let archive = SeasonArchive(set:17,matches:Array(matches.suffix(30)),checkedAt:.now,indexedGames:76,indexedTop4:39)
        try store.ingestArchive(archive)
        XCTAssertEqual(TrackerStore(directory:dir).matches(set:17).count,30)
        XCTAssertThrowsError(try store.ingestArchive(SeasonArchive(set:17,matches:[matches[0]],checkedAt:.now,indexedGames:nil,indexedTop4:nil)))
        try store.saveProfile(try XCTUnwrap(RiotIdentity("Other#EUW",region:"euw1")))
        XCTAssertTrue(store.archives.isEmpty)
    }
    @MainActor func testLocalGoalsNotesAndDialoguePersistAndStayScopedToAccountAndSet() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let store = AnalystStore(directory:dir)
        let matches = try sample(), account = "fixture:euw1"
        let report = MatchAnalyst(matches:matches,set:18)
        store.start(.stability,account:account,report:report)
        store.note("Mon contexte",match:matches[0].id,account:account)
        store.ask("Que montrent mes objets ?",account:account,report:report)
        let saved = AnalystStore(directory:dir)
        XCTAssertEqual(saved.state.goals[account]?.baseline.count,30)
        XCTAssertEqual(saved.state.notes[account+":"+matches[0].id],"Mon contexte")
        XCTAssertEqual(saved.state.conversations[saved.scope(account:account,report:report)]?.count,1)
        XCTAssertNil(saved.state.conversations[saved.scope(account:account,report:MatchAnalyst(matches:matches,set:17))])
        saved.start(.economy,account:"other",report:report)
        saved.erase(account:account)
        let erased = AnalystStore(directory:dir)
        XCTAssertNil(erased.state.goals[account]); XCTAssertTrue(erased.state.notes.isEmpty)
        XCTAssertTrue(erased.state.conversations.isEmpty); XCTAssertNotNil(erased.state.goals["other"])
    }
    func testLegacyTrackerCacheStillDecodesWithoutEquipmentOrSeasons() throws {
        let data = Data(#"{"profiles":[],"points":{},"region":"euw1","riotID":""}"#.utf8)
        let state = try JSONDecoder().decode(TrackerState.self,from:data)
        XCTAssertNil(state.archives)
        let unit = try JSONDecoder().decode(TrackedMatch.Unit.self,from:Data(#"{"key":"old","stars":2,"items":["one","two"]}"#.utf8))
        XCTAssertNil(unit.equipment); XCTAssertTrue(unit.completeItems.isEmpty)
    }
    func testTrainingFollowUpUsesFirstTenNewSoloMatchesInTheSameSet() throws {
        let matches = try sample()
        let set18 = matches.filter { $0.set == 18 }.sorted { $0.timestamp < $1.timestamp }
        let first = try XCTUnwrap(set18.first)
        let goal = TrainingGoal(topic:.stability,startedAt:first.date,set:18,baseline:[first])
        let result = goal.followUp(in:matches + matches)
        XCTAssertEqual(result.map(\.id),Array(set18.dropFirst().prefix(10)).map(\.id))
        XCTAssertEqual(result.count,10)
        XCTAssertTrue(result.allSatisfy { $0.set == 18 && $0.queue == 1100 })
    }
    @MainActor func testGuideDoesNotCallASecondCarryTheTank() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let meta = MetaStore(directory:dir)
        let guide = try XCTUnwrap(LiveGuideCatalogue.guides.first { $0.comp_id == "hexa-ahri-zyra" })
        let brief = GuideBrief(comp:guide,reference:meta.live?.reference,stage:.transition)
        XCTAssertEqual(brief.primary,"DA_18_Ahri")
        XCTAssertNotEqual(brief.tank,"DA_18_Zyra")
        XCTAssertEqual(brief.checkpoints.count,3)
        XCTAssertTrue(brief.checkpoints.joined().contains("4-2"))
    }
    @MainActor func testArchiveDefaultsToAUsableCatalogueEvenAfterAnEmptyBuildWasCached() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        let empty = PatchSnapshot(pack:MetaPack(data:[],retrievedAt:Date.now.ISO8601Format(),set:"18",patch:"18.7"),reference:nil)
        try JSONEncoder().encode([empty]).write(to:dir.appendingPathComponent("patch-archives.json"))
        let meta = MetaStore(directory:dir)
        meta.select(.archives)
        XCTAssertFalse(try XCTUnwrap(meta.pack).data.isEmpty)
        meta.select(.archives,archiveID:empty.id)
        XCTAssertEqual(meta.archive?.id,empty.id)
    }
}
