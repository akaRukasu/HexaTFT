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
        app.buttons["Codex"].tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 8))
        snapshot("04-codex")
        app.navigationBars["Codex"].buttons.firstMatch.tap()
        app.buttons["Sources"].tap()
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
    @MainActor func testVisualStagesAndChampionRecipes() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Archives"].tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meta-card-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15)); card.tap()
        let mode = app.segmentedControls["guide-mode"]
        for _ in 0..<4 where !mode.isHittable { app.swipeUp() }
        XCTAssertTrue(mode.waitForExistence(timeout: 8))
        mode.buttons["Niveaux"].tap()
        app.buttons["guide-level-6"].tap()
        let unit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "board-unit-")).firstMatch
        XCTAssertTrue(unit.waitForExistence(timeout: 8))
        snapshot("06-guide-niveau-6")
        mode.buttons["Final"].tap()
        let champion = app.buttons.matching(NSPredicate(format: "identifier IN %@", ["board-unit-DA_Draven18", "board-unit-DA_18_Maokai"])).firstMatch
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
        for _ in 0..<3 where !app.staticTexts["Les pistes du dernier guide PBE retrouvé"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Les pistes du dernier guide PBE retrouvé"].exists)
        snapshot("09-pbe")
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
        let publicProfile = app.descendants(matching: .any).matching(identifier: "tracker-public-profile").firstMatch
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 8), app.debugDescription)
        let identity = app.descendants(matching: .any).matching(identifier: "tracker-identity").firstMatch
        XCTAssertTrue(identity.label.contains("Tactikk#EUW"))
        snapshot("15-tracker-profil")
        app.terminate()
        app.launch()
        app.tabBars.buttons["Tracker"].tap()
        XCTAssertTrue(publicProfile.waitForExistence(timeout: 8))
    }
    @MainActor func testLiveGuideShowsPlayableBoardAndItemPlan() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["LIVE EUW"].tap()
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
        let radar = app.buttons["meta-radar"]
        XCTAssertTrue(radar.waitForExistence(timeout: 8))
        snapshot("16-home-radar")
        radar.tap()
        let card = app.descendants(matching: .any).matching(identifier: "observation-codex-roncier").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["Radar des compos"].exists)
        snapshot("17-multi-sources")
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
    }
    @MainActor private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
