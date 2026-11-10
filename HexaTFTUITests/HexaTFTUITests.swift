import XCTest

final class HexaTFTUITests: XCTestCase {
    @MainActor func testBrowsePinAndSources() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["La méta, à portée de main."].waitForExistence(timeout: 15))
        app.buttons["Actualiser les compositions"].tap()
        let refreshed = app.staticTexts["Compositions actualisées."]
        XCTAssertTrue(refreshed.waitForExistence(timeout: 45))
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
            XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))
            let content = NSPredicate { _, _ in app.webViews.firstMatch.staticTexts.count > 5 }
            expectation(for: content, evaluatedWith: nil)
            waitForExpectations(timeout: 45)
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
    @MainActor private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
