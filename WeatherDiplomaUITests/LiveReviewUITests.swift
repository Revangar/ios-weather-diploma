import XCTest

/// Runs the normal app and real URLSession/Open-Meteo. No app test flags or transport override.
@MainActor
final class LiveReviewUITests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "live-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func waitFresh(_ app: XCUIApplication) {
        let status = app.staticTexts["weather-status"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 25))
        let fresh = NSPredicate(format: "label BEGINSWITH 'Обновлено'")
        expectation(for: fresh, evaluatedWith: status)
        waitForExpectations(timeout: 35)
        XCTAssertTrue(app.staticTexts["current-temperature"].firstMatch.exists)
    }
    private func add(_ app: XCUIApplication, query: String, country: String) {
        app.buttons["add-city"].tap()
        let field = app.textFields["city-query"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(query)
        app.alerts.buttons["Найти"].tap()
        let choice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", country)).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 30))
        choice.tap()
        waitFresh(app)
    }
    func testLiveUserJourney() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WEATHER_RUN_LIVE_REVIEW"] == "1",
                          "Opt-in live integration review: use a fresh review-owned Simulator")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-location"].waitForExistence(timeout: 15))
        capture("01-onboarding")
        app.buttons["onboarding-location"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Запретить", "Не разрешать", "Don’t Allow", "Don't Allow"])).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 15)); deny.tap()
        XCTAssertTrue(app.alerts["Погода"].waitForExistence(timeout: 10))
        capture("02-location-denied")
        app.alerts.buttons["Понятно"].tap()
        XCTAssertTrue(app.buttons["empty-add-city"].exists)
        capture("03-empty")
        add(app, query: "Moscow", country: "Россия")
        let card = app.otherElements["current-weather-card"].firstMatch
        if card.exists { print("REVIEW_GEOMETRY card=\(card.frame)") }
        capture("04-moscow")
        app.buttons["open-hours"].tap()
        XCTAssertTrue(app.tables["hourly-detail"].waitForExistence(timeout: 8))
        capture("05-hours")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let weather = app.tables["weather-table"]
        for _ in 0..<6 where !app.cells["day-0"].isHittable { weather.swipeUp() }
        app.cells["day-0"].tap()
        XCTAssertTrue(app.tables["daily-detail"].waitForExistence(timeout: 8))
        app.buttons["select-day-1"].tap()
        capture("06-daily")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for _ in 0..<8 where !app.cells["day-6"].isHittable { weather.swipeUp() }
        XCTAssertTrue(app.cells["day-6"].isHittable)
        capture("07-seven-days")
        add(app, query: "Berlin", country: "Германия")
        capture("08-berlin")
        // Real gestures in the weather pager (not in the nested hourly collection).
        for index in 0..<8 {
            let area = app.tables["weather-table"].firstMatch
            let left = area.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.22))
            let right = area.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.22))
            if index.isMultiple(of: 2) { left.press(forDuration: 0.05, thenDragTo: right, withVelocity: .fast, thenHoldForDuration: 0) }
            else { right.press(forDuration: 0.05, thenDragTo: left, withVelocity: .fast, thenHoldForDuration: 0) }
            XCTAssertTrue(app.buttons["open-settings"].isHittable)
        }
        waitFresh(app)
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.segmentedControls["setting-temperature"].waitForExistence(timeout: 5))
        app.segmentedControls["setting-temperature"].buttons["°F"].tap()
        app.segmentedControls["setting-wind"].buttons["миль/ч"].tap()
        app.segmentedControls["setting-time"].buttons["12"].tap()
        capture("09-settings")
        app.buttons["apply-settings"].tap()
        XCTAssertTrue(app.staticTexts["current-temperature"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["current-temperature"].firstMatch.label.contains("°F"))
        app.terminate(); app.launch()
        XCTAssertFalse(app.buttons["onboarding-location"].exists)
        waitFresh(app)
        XCTAssertTrue(app.staticTexts["current-temperature"].firstMatch.label.contains("°F"))
        capture("10-relaunch")
        app.buttons["open-settings"].tap()
        app.staticTexts["Мои города"].tap()
        XCTAssertTrue(app.navigationBars["Мои города"].waitForExistence(timeout: 5))
        let berlin = app.cells.containing(.staticText, identifier: "Берлин").firstMatch
        berlin.swipeLeft()
        let delete = app.buttons.matching(NSPredicate(format: "label IN %@", ["Удалить", "Delete"])).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5)); delete.tap()
        capture("11-delete-city")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["city-indicator"].firstMatch.label.contains("1 из 1"))
        // Reset authorization for this review-owned app/device, not its data.
        app.terminate(); app.resetAuthorizationStatus(for: .location); app.launch()
        app.buttons["open-settings"].tap(); app.staticTexts["Моё местоположение"].tap()
        let allow = springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'При использовании' OR label CONTAINS 'While Using'")).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 15)); allow.tap()
        let duplicate = app.alerts.buttons["Понятно"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 30))
        XCTAssertTrue(app.alerts.staticTexts["Этот город уже добавлен."].exists)
        duplicate.tap()
        XCTAssertTrue(app.staticTexts["city-indicator"].firstMatch.label.contains("1 из 1"))
        waitFresh(app)
        capture("12-location-allowed")
        XCUIDevice.shared.orientation = .landscapeLeft
        capture("13-landscape")
        XCUIDevice.shared.orientation = .portrait
    }
    func testZProcessOfflineCache() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WEATHER_RUN_LIVE_REVIEW"] == "1",
                          "Opt-in process network-denial review; no host network changes")
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["WEATHER_REVIEW_NETWORK_DYLIB"])
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = ["DYLD_INSERT_LIBRARIES": path]
        app.launch()
        let status = app.staticTexts["weather-status"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "label CONTAINS 'Офлайн'"), evaluatedWith: status)
        waitForExpectations(timeout: 30)
        XCTAssertTrue(app.staticTexts["current-temperature"].firstMatch.exists)
        capture("14-offline-cache")
        app.buttons["open-hours"].tap()
        XCTAssertTrue(app.tables["hourly-detail"].waitForExistence(timeout: 5))
        capture("15-offline-hours")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let table = app.tables["weather-table"]
        for _ in 0..<5 where !app.cells["day-0"].isHittable { table.swipeUp() }
        app.cells["day-0"].tap()
        XCTAssertTrue(app.tables["daily-detail"].waitForExistence(timeout: 5))
        capture("16-offline-day")
        app.terminate()
        app.launchEnvironment = [:]
        app.launch()
        waitFresh(app)
        capture("17-network-restored")
    }

}
