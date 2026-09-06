import XCTest

final class CompanionUITests: XCTestCase {
    @MainActor
    func testExamplePeriodsLanguageAndRemoval() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["showExample"].waitForExistence(timeout: 10))
        app.buttons["showExample"].tap()
        XCTAssertTrue(app.staticTexts["Usage history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Example · fictional data"].exists)
        capture("English — 7 days")

        let period = app.segmentedControls["historyPeriod"]
        XCTAssertTrue(period.waitForExistence(timeout: 5))
        period.buttons["30 days"].tap()
        XCTAssertTrue(app.staticTexts["Recorded tokens · 30/30 days"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["options"].tap()
        if app.buttons["Language"].waitForExistence(timeout: 2) { app.buttons["Language"].tap() }
        XCTAssertTrue(app.buttons["Lietuvių"].waitForExistence(timeout: 5))
        app.buttons["Lietuvių"].tap()
        XCTAssertTrue(app.staticTexts["Naudojimo istorija"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pavyzdys · išgalvoti duomenys"].exists)
        capture("Lietuviškai — 30 dienų")
        app.swipeUp()
        capture("Daily chart")

        app.buttons["options"].tap()
        app.buttons["Pašalinti suvestinę…"].tap()
        XCTAssertTrue(app.buttons["Pašalinti suvestinę"].waitForExistence(timeout: 5))
        app.buttons["Pašalinti suvestinę"].tap()
        XCTAssertTrue(app.buttons["showExample"].waitForExistence(timeout: 5))
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
