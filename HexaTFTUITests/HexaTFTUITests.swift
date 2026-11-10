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
        let publicProfile = app.webViews.firstMatch
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Tactikk#EUW"].exists ||
                      app.descendants(matching: .any).matching(identifier: "tracker-identity").firstMatch.exists)
        let profileTabs = app.segmentedControls["tracker-profile-tabs"]
        XCTAssertTrue(profileTabs.buttons["Tactics.Tools"].isSelected)
        snapshot("15-tracker-profil")
        profileTabs.buttons["Mon suivi Hexa"].tap()
        XCTAssertTrue(app.buttons["Modifier le profil"].waitForExistence(timeout: 8))
        profileTabs.buttons["Tactics.Tools"].tap()
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 8))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Tracker"].tap()
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 8))
    }
    @MainActor func testLiveGuideShowsPlayableBoardAndItemPlan() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["LIVE EUW"].tap()
        app.segmentedControls["meta-library"].buttons["Guides"].tap()
        let card = app.buttons["meta-card-hexa-ahri-zyra"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        for _ in 0..<3 where !card.isHittable { app.swipeUp() }
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
    @MainActor func testRadarPatchDetailsAndEsport() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["LIVE EUW"].tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "observation-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertEqual(card.identifier, "observation-metastats-raptor")
        for _ in 0..<3 where !card.isHittable { app.swipeUp() }
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
