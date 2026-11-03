import XCTest

final class HexaTFTUITests: XCTestCase {
    @MainActor func testBrowsePinAndSources() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["La méta, à portée de main."].waitForExistence(timeout: 15))
        snapshot("01-meta")
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "meta-card-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.buttons["Suivre dans Partie"].waitForExistence(timeout: 10))
        snapshot("02-composition")
        app.buttons["Suivre dans Partie"].tap()
        app.tabBars.buttons["Partie"].tap()
        XCTAssertTrue(app.staticTexts["Plateau cible"].waitForExistence(timeout: 8))
        snapshot("03-partie")
        app.tabBars.buttons["Codex"].tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 8))
        snapshot("04-codex")
        app.tabBars.buttons["Sources"].tap()
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
    @MainActor private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
