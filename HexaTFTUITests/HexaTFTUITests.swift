import XCTest

final class HexaTFTUITests: XCTestCase {
    @MainActor func testBrowsePinAndSources() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Archives"].waitForExistence(timeout: 15))
        app.buttons["Archives"].tap()
        snapshot("01-meta")
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meta-card-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.buttons["Suivre dans Partie"].waitForExistence(timeout: 10))
        snapshot("02-composition")
        app.buttons["Suivre dans Partie"].tap()
        app.tabBars.buttons["Partie"].tap()
        XCTAssertTrue(app.staticTexts["Guide visuel"].waitForExistence(timeout: 8))
        snapshot("03-partie")
        app.tabBars.buttons["Plus"].tap()
        let sources = app.buttons["Sources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 8))
        sources.tap()
        XCTAssertTrue(app.buttons["MetaTFT"].waitForExistence(timeout: 8))
        for source in ["Mobalytics", "MetaTFT", "Blitz"] {
            app.buttons[source].tap()
            if source == "MetaTFT" {
                XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))
            } else {
                XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "source-original-" + source).firstMatch.waitForExistence(timeout: 8))
            }
            snapshot("05-source-" + source)
        }
    }
    @MainActor func testCodexOpensFromLibrary() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Plus"].tap()
        let codex = app.buttons["Codex"]
        XCTAssertTrue(codex.waitForExistence(timeout: 8))
        codex.tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 8))
        snapshot("04-codex")
    }
    @MainActor func testVisualStagesAndChampionRecipes() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Archives"].tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meta-card-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        XCTAssertEqual(card.identifier, "meta-card-c_3ueqmaaq")
        card.tap()
        let mode = app.segmentedControls["guide-mode"]
        for _ in 0..<4 where !mode.isHittable { app.swipeUp() }
        XCTAssertTrue(mode.waitForExistence(timeout: 8))
        mode.buttons["Niveaux"].tap()
        app.buttons["guide-level-6"].tap()
        let unit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "board-unit-")).firstMatch
        XCTAssertTrue(unit.waitForExistence(timeout: 8))
        snapshot("06-guide-niveau-6")
        mode.buttons["Final"].tap()
        let champion = app.buttons["board-unit-DA_18_Ahri"]
        XCTAssertTrue(champion.waitForExistence(timeout: 8))
        for _ in 0..<3 where !champion.isHittable { app.swipeUp() }
        champion.tap()
        XCTAssertTrue(app.staticTexts["equipment-champion-title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Le trio de référence"].exists)
        for _ in 0..<3 where !app.staticTexts["Fabriquer cet objet"].firstMatch.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Fabriquer cet objet"].firstMatch.exists)
        snapshot("07-objets-recettes")
        app.buttons["Fermer"].tap()
        for _ in 0..<5 where !mode.isHittable { app.swipeDown() }
        mode.buttons["Stades"].tap()
        let stage = app.buttons["guide-stage-3-2"]
        stage.tap()
        XCTAssertTrue(app.staticTexts["Milieu de partie"].exists)
        snapshot("08-guide-milieu")
    }
    @MainActor func testUltimatePBEAndTrackerNavigation() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["PBE"].tap()
        let pbeCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meta-card-pbe-")).firstMatch
        XCTAssertTrue(pbeCard.waitForExistence(timeout: 8))
        snapshot("09-pbe")
        pbeCard.tap()
        XCTAssertTrue(app.segmentedControls["guide-mode"].waitForExistence(timeout: 8))
        snapshot("21-pbe-guide")
        app.tabBars.buttons["Patches"].tap()
        XCTAssertTrue(app.navigationBars["Patches"].exists)
        XCTAssertTrue(app.staticTexts["Laboratoire PBE"].exists)
        snapshot("10-patches")
        app.tabBars.buttons["Tracker"].tap()
        app.buttons["Ajouter mon compte"].tap()
        let id = app.textFields["Pseudo#TAG"]
        XCTAssertTrue(id.waitForExistence(timeout: 8))
        XCTAssertFalse(app.textFields["Adresse HTTPS"].exists)
        XCTAssertFalse(app.secureTextFields.firstMatch.exists)
        snapshot("11-tracker")
        id.tap()
        id.typeText("Tactikk#EUW")
        XCTAssertEqual(id.value as? String, "Tactikk#EUW")
        let save = app.buttons["tracker-save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let profileTabs = app.segmentedControls["tracker-profile-tabs"]
        XCTAssertTrue(profileTabs.waitForExistence(timeout: 8))
        XCTAssertTrue(profileTabs.buttons["Vue d’ensemble"].isSelected)
        profileTabs.buttons["Tactics.Tools"].tap()
        let publicProfile = app.webViews.firstMatch
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Tactikk#EUW"].exists ||
                      app.descendants(matching: .any).matching(identifier: "tracker-identity").firstMatch.exists)
        XCTAssertTrue(profileTabs.buttons["Tactics.Tools"].isSelected)
        snapshot("15-tracker-profil")
        profileTabs.buttons["Vue d’ensemble"].tap()
        app.buttons["Options du compte"].tap()
        XCTAssertTrue(app.buttons["Modifier le profil"].waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Tracker"].tap()
        XCTAssertTrue(profileTabs.waitForExistence(timeout: 8))
        XCTAssertTrue(profileTabs.buttons["Vue d’ensemble"].isSelected)
    }
    @MainActor func testLiveGuideShowsPlayableBoardAndItemPlan() {
        let app = XCUIApplication()
        app.launchEnvironment["HEXA_META_OFFLINE_TEST"] = "1"
        app.launch()
        app.buttons["LIVE EUW"].tap()
        app.segmentedControls["meta-library"].buttons["Guides"].tap()
        let card = app.buttons["meta-card-hexa-ahri-zyra"]
        for _ in 0..<12 {
            if card.isHittable { break }
            app.swipeUp()
        }
        guard card.isHittable else {
            XCTFail("Le guide Ahri · Zyra est introuvable dans le catalogue LIVE.")
            return
        }
        snapshot("12-live-guides")
        card.tap()
        let mode = app.segmentedControls["guide-mode"]
        for _ in 0..<4 where !mode.isHittable { app.swipeUp() }
        XCTAssertTrue(mode.waitForExistence(timeout: 8))
        mode.buttons["Final"].tap()
        let ahri = app.buttons["board-unit-DA_18_Ahri"]
        for _ in 0..<4 where !ahri.isHittable { app.swipeUp() }
        XCTAssertTrue(ahri.isHittable)
        snapshot("13-live-plateau")
        ahri.tap()
        XCTAssertTrue(app.staticTexts["Le trio de référence"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Fabrique d’abord Shojin")).firstMatch.exists)
        snapshot("14-live-objets")
    }
    @MainActor func testCurrentMetaShowsPublishedRosterAndConditions() throws {
        let app = XCUIApplication()
        let json = """
        ["$","$L2",null,{"data":{
            "status":"ready","generation":{"set":18,"patch":"18.6"},
            "metadata":{"currentPatch":"18.6","updatedAt":"\(Date.now.ISO8601Format())","sliceApplied":true},
            "filters":{"region":"global","tier":"PLATINUM+","window":72},
            "comps":[{"id":"morgana","name":"Vanguard Morgana","difficulty":3,"strategyLevel":8,
                      "stats":{"avgPlacement":3.85,"winRate":0.25,"top4Rate":0.60,"count":41163,"pickRate":0.018},
                      "units":[{"key":"DA_18_Morgana","role":"carry","items":[{"key":"DA_VoidStaff"}]},
                               {"key":"DA_Sentinel18","role":"tank"}],
                      "requirementBadges":[{"name":"Emblème test"}]}]
        }}]
        """
        let payload = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let line = "1:" + String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self) + "\n"
        let chunk = String(decoding: try JSONSerialization.data(withJSONObject: [1, line]), as: UTF8.self)
        app.launchEnvironment["HEXA_OPGG_META_FIXTURE"] = "<script>self.__next_f.push(\(chunk))</script>"
        app.launch()
        app.buttons["LIVE EUW"].tap()
        let refresh = app.buttons["meta-refresh-now"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["meta-current-sources"].exists)
        let card = app.buttons["meta-opgg-morgana"]
        for _ in 0..<6 {
            if card.isHittable { break }
            app.swipeUp()
        }
        guard card.isHittable else {
            XCTFail("Le relevé OP.GG est absent de l’accueil.")
            return
        }
        snapshot("27-meta-opgg")
        card.tap()
        XCTAssertTrue(app.navigationBars["Composition"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Quand jouer cette compo"].exists)
        XCTAssertTrue(app.staticTexts["Emblème test"].exists)
        snapshot("28-meta-conditions")
        let unit = app.buttons["board-unit-DA_18_Morgana"]
        for _ in 0..<4 where !unit.isHittable { app.swipeUp() }
        XCTAssertTrue(unit.isHittable)
        app.navigationBars["Composition"].buttons.firstMatch.tap()
        let sources = app.buttons["meta-current-sources"]
        for _ in 0..<5 where !sources.isHittable { app.swipeDown() }
        guard sources.isHittable else {
            XCTFail("L’accès aux pages actuelles est introuvable.")
            return
        }
        sources.tap()
        let picker = app.segmentedControls["meta-web-source-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 8))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 8))
        for provider in ["Tactics.Tools", "MetaStats.gg", "TFT Codex"] {
            picker.buttons[provider].tap()
            XCTAssertTrue(picker.buttons[provider].isSelected)
        }
        XCTAssertTrue(app.buttons["Recharger la page"].exists)
    }
    @MainActor func testTrackerNativeOverviewOpensAnOPGGMatch() {
        let app = XCUIApplication()
        app.launchEnvironment["HEXA_TRACKER_UI_FIXTURE"] = """
        {"region":"euw1","riotID":"Fixture#EUW","selected":"opgg:fixture#euw:euw1","points":{},
         "profiles":[{"id":"opgg:fixture#euw","region":"euw1","riotID":"Fixture#EUW","source":"OP.GG","observedAt":1794271042,
         "ranks":[{"queue":"RANKED_TFT","tier":"SILVER","division":"II","lp":22,"games":14,"top4Count":6}],
         "matches":[{"id":"EUW1_fixture","timestamp":1794271042,"patch":"18.6","set":18,"queue":1100,"placement":2,
         "level":8,"units":[{"key":"DA_18_Hecarim","stars":2,"items":["DA_WarmogsArmor"]}],"traits":[],"augments":[],"lobby":[],"source":"OP.GG"}]}]}
        """
        app.launch()
        app.tabBars.buttons["Tracker"].tap()
        XCTAssertTrue(app.staticTexts["Argent II"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["22 LP"].exists)
        XCTAssertTrue(app.segmentedControls["tracker-native-tabs"].exists)
        snapshot("25-tracker-vue-ensemble")
        let match = app.buttons["tracker-recent-EUW1_fixture"]
        for _ in 0..<5 where !match.isHittable { app.swipeUp() }
        XCTAssertTrue(match.isHittable)
        match.tap()
        XCTAssertTrue(app.navigationBars["Partie terminée"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "OP.GG")).firstMatch.exists)
        snapshot("26-tracker-partie")
    }
    @MainActor func testRadarPatchDetailsAndEsport() {
        let app = XCUIApplication()
        app.launchEnvironment["HEXA_META_OFFLINE_TEST"] = "1"
        app.launch()
        app.buttons["LIVE EUW"].tap()
        XCTAssertTrue(app.staticTexts["Relevé intégré à cette version"].exists)
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "observation-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertEqual(card.identifier, "observation-metastats-raptor")
        for _ in 0..<3 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.label.contains("8 unités") ||
                      card.staticTexts["Plateau conseillé par Hexa · 8 unités"].exists)
        snapshot("16-home-radar")
        card.tap()
        XCTAssertTrue(app.navigationBars["Composition"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Top 4")).firstMatch.exists)
        let mode = app.segmentedControls["guide-mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 8))
        XCTAssertTrue(mode.buttons["Final"].isSelected)
        snapshot("17-multi-sources")
        let raptor = app.buttons["board-unit-DA_CrimsonRaptor18"]
        for _ in 0..<4 where !raptor.isHittable { app.swipeUp() }
        XCTAssertTrue(raptor.isHittable)
        snapshot("23-radar-plateau")
        raptor.tap()
        XCTAssertTrue(app.staticTexts["Le trio de référence"].waitForExistence(timeout: 8))
        let recipe = app.staticTexts["Fabriquer cet objet"].firstMatch
        for _ in 0..<3 where !recipe.isHittable { app.swipeUp() }
        XCTAssertTrue(recipe.exists)
        snapshot("24-radar-objets")
        app.buttons["Fermer"].tap()
        app.tabBars.buttons["Patches"].tap()
        let notes = app.buttons["Notes du patch 18.6"]
        for _ in 0..<3 where !notes.isHittable { app.swipeUp() }
        XCTAssertTrue(notes.exists)
        notes.tap()
        XCTAssertTrue(app.navigationBars["Patch 18.6"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "patch-category").firstMatch.exists)
        snapshot("18-release-notes")
        app.tabBars.buttons["Plus"].tap()
        app.buttons["Esport"].tap()
        let tabs = app.segmentedControls["esport-tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 8))
        snapshot("19-esport")
        tabs.buttons["Calendrier"].tap()
        let phases = app.staticTexts["Le parcours du mondial"]
        for _ in 0..<3 where !phases.isHittable { app.swipeUp() }
        XCTAssertTrue(phases.exists)
        XCTAssertTrue(app.staticTexts["13 h chaque jour · heure de Paris"].exists)
        snapshot("20-esport-calendrier")
        for _ in 0..<4 where !tabs.isHittable { app.swipeDown() }
        tabs.buttons["Joueurs"].tap()
        let players = app.segmentedControls["esport-player-sections"]
        XCTAssertTrue(players.waitForExistence(timeout: 8))
        players.buttons["Clubs FR"].tap()
        XCTAssertTrue(app.staticTexts["Gentle Mates"].waitForExistence(timeout: 8))
        snapshot("22-esport-clubs")
    }
    @MainActor private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
