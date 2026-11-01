import XCTest

@MainActor
final class WeatherDiplomaUITests: XCTestCase {
    private func launch(_ namespace: String, reset: Bool = true, offline: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture-network"]
        if reset { app.launchArguments.append("--reset-test-state") }
        if offline { app.launchArguments.append("--offline") }
        app.launchEnvironment["WEATHER_TEST_NAMESPACE"] = namespace
        app.launch()
        return app
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func skip(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["onboarding-skip"].waitForExistence(timeout: 10))
        app.buttons["onboarding-skip"].tap()
    }
    private func addCity(_ app: XCUIApplication, query: String, country: String) {
        app.buttons["add-city"].tap()
        let field = app.textFields["city-query"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(query)
        app.alerts.buttons["Найти"].tap()
        let match = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", country)).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 8))
        match.tap()
        XCTAssertTrue(app.staticTexts["current-temperature"].waitForExistence(timeout: 10))
    }
    func testCitiesForecastDetailsSettingsAndOfflineRelaunch() {
        let app = launch("journey")
        screenshot("01-onboarding")
        skip(app)
        XCTAssertTrue(app.buttons["empty-add-city"].waitForExistence(timeout: 5))
        screenshot("02-empty")
        addCity(app, query: "Moscow", country: "Россия")
        screenshot("03-weather-moscow")
        app.buttons["open-hours"].tap()
        XCTAssertTrue(app.tables["hourly-detail"].waitForExistence(timeout: 5))
        screenshot("04-hourly")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["forecast-25"].tap()
        XCTAssertTrue(app.alerts["Доступно 7 дней"].waitForExistence(timeout: 5))
        app.alerts.buttons["Понятно"].tap()
        let table = app.tables["weather-table"]
        for _ in 0..<4 where !app.cells["day-0"].isHittable { table.swipeUp() }
        app.cells["day-0"].tap()
        XCTAssertTrue(app.tables["daily-detail"].waitForExistence(timeout: 5))
        app.buttons["select-day-1"].tap()
        screenshot("05-daily")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        addCity(app, query: "Berlin", country: "Германия")
        XCTAssertTrue(app.staticTexts["city-indicator"].label.contains("2 из 2"))
        screenshot("06-two-cities")
        // Anchor the gesture to the pager's weather area; screen coordinates hit the hourly
        // collection on iPad once the current-weather card is compacted.
        let weatherArea = app.tables["weather-table"].firstMatch
        let from = weatherArea.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.17))
        let to = weatherArea.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.17))
        from.press(forDuration: 0.1, thenDragTo: to)
        XCTAssertTrue(app.navigationBars["Москва"].waitForExistence(timeout: 5))
        app.buttons["open-settings"].tap()
        let temp = app.segmentedControls["setting-temperature"]
        XCTAssertTrue(temp.waitForExistence(timeout: 5))
        temp.buttons["°F"].tap()
        app.segmentedControls["setting-time"].buttons["12"].tap()
        screenshot("07-settings")
        app.buttons["Установить"].tap()
        XCTAssertTrue(app.staticTexts["current-temperature"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["current-temperature"].label.contains("°F"))
        app.terminate()
        let offline = launch("journey", reset: false, offline: true)
        let status = offline.staticTexts["weather-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let predicate = NSPredicate(format: "label CONTAINS 'Офлайн'")
        expectation(for: predicate, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(offline.staticTexts["current-temperature"].label.contains("°F"))
        XCTAssertFalse(offline.buttons["onboarding-skip"].exists)
        screenshot("08-offline-cache")
    }
    func testNonexistentDuplicateAndOfflineWithoutCache() {
        let app = launch("errors")
        skip(app)
        app.buttons["add-city"].tap()
        app.textFields["city-query"].tap()
        app.textFields["city-query"].typeText("zzzzzzzzzz")
        app.alerts.buttons["Найти"].tap()
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Город не найден'")).firstMatch.waitForExistence(timeout: 5))
        screenshot("09-not-found")
        app.alerts.buttons["Понятно"].tap()
        addCity(app, query: "Moscow", country: "Россия")
        addCity(app, query: "Moscow", country: "Россия")
        XCTAssertTrue(app.alerts.staticTexts["Этот город уже добавлен."].waitForExistence(timeout: 5))
        app.alerts.buttons["Понятно"].tap()
        XCTAssertTrue(app.staticTexts["city-indicator"].label.contains("1 из 1"))
        app.terminate()
        let offline = launch("fresh-offline", offline: true)
        skip(offline)
        offline.buttons["add-city"].tap()
        offline.textFields["city-query"].tap()
        offline.textFields["city-query"].typeText("Moscow")
        offline.alerts.buttons["Найти"].tap()
        XCTAssertTrue(offline.alerts["Погода"].waitForExistence(timeout: 5))
        screenshot("10-offline-empty")
    }
    func testLocationPermissionDeniedKeepsManualEntry() {
        let app = launch("denied")
        app.terminate()
        app.resetAuthorizationStatus(for: .location)
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-location"].waitForExistence(timeout: 10))
        app.buttons["onboarding-location"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS[c] 'разреш'"))
        let exact = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Don’t Allow", "Don’t allow", "Не разрешать", "Запретить", "Don't Allow"])).firstMatch
        if exact.waitForExistence(timeout: 10) { exact.tap() }
        else { XCTFail("System location denial button missing: \(deny.allElementsBoundByIndex.map(\.label))") }
        XCTAssertTrue(app.alerts["Погода"].waitForExistence(timeout: 10))
        app.alerts.buttons["Понятно"].tap()
        XCTAssertTrue(app.buttons["empty-add-city"].exists)
        screenshot("11-location-denied")
    }
    func testLocationPermissionAllowed() {
        let app = launch("allowed")
        app.terminate()
        app.resetAuthorizationStatus(for: .location)
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-location"].waitForExistence(timeout: 10))
        app.buttons["onboarding-location"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'While Using' OR label CONTAINS 'При использовании' OR label CONTAINS 'использовании приложения'")).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 10))
        allow.tap()
        XCTAssertTrue(app.staticTexts["current-temperature"].waitForExistence(timeout: 40))
        screenshot("12-location-allowed")
    }
    func testAdaptiveLandscapeAndLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--fixture-network", "--reset-test-state",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launchEnvironment["WEATHER_TEST_NAMESPACE"] = "adaptive"
        app.launch()
        XCTAssertTrue(app.buttons["onboarding-skip"].waitForExistence(timeout: 10))
        for _ in 0..<8 where !app.buttons["onboarding-skip"].isHittable { app.scrollViews.firstMatch.swipeUp() }
        app.buttons["onboarding-skip"].tap()
        addCity(app, query: "Moscow", country: "Россия")
        assertWeatherHeaderFits(app)
        screenshot("13-accessibility-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.tables["weather-table"].waitForExistence(timeout: 5))
        assertWeatherHeaderFits(app)
        screenshot("14-accessibility-landscape")
        let table = app.tables["weather-table"]
        for _ in 0..<12 where !app.cells["day-6"].isHittable { table.swipeUp() }
        XCTAssertTrue(app.cells["day-6"].isHittable)
        screenshot("15-seven-days-large-text")
    }
    private func assertWeatherHeaderFits(_ app: XCUIApplication) {
        let table = app.tables["weather-table"].firstMatch.frame
        XCTAssertLessThanOrEqual(table.width, app.frame.width + 1, "Pager must fit the device width")
        XCTAssertGreaterThanOrEqual(table.minX, app.frame.minX - 1)
        XCTAssertLessThanOrEqual(table.maxX, app.frame.maxX + 1)
        for element in [app.otherElements["current-weather-card"].firstMatch,
                        app.staticTexts["weather-status"].firstMatch,
                        app.staticTexts["current-temperature"].firstMatch] {
            XCTAssertTrue(element.exists)
            let frame = element.frame
            XCTAssertGreaterThanOrEqual(frame.minX, table.minX - 1, "Header extends beyond the leading edge")
            XCTAssertLessThanOrEqual(frame.maxX, table.maxX + 1, "Header extends beyond the trailing edge")
        }
    }
    func testCityManagementAndLocationFromSettings() {
        let app = launch("management")
        skip(app)
        addCity(app, query: "Moscow", country: "Россия")
        app.buttons["open-settings"].tap()
        app.staticTexts["Мои города"].tap()
        XCTAssertTrue(app.navigationBars["Мои города"].waitForExistence(timeout: 5))
        let city = app.cells.containing(.staticText, identifier: "Москва").firstMatch
        city.swipeLeft()
        let delete = app.buttons.matching(NSPredicate(format: "label IN %@", ["Delete", "Удалить"])).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertEqual(app.cells.count, 0)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["empty-add-city"].waitForExistence(timeout: 5))
        screenshot("16-city-removed")
        app.terminate()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments.removeAll { $0 == "--reset-test-state" }
        app.launch()
        app.buttons["open-settings"].tap()
        app.staticTexts["Моё местоположение"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Запретить", "Не разрешать", "Don’t Allow", "Don't Allow"])).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 10))
        deny.tap()
        XCTAssertTrue(app.alerts["Погода"].waitForExistence(timeout: 5))
        app.alerts.buttons["Понятно"].tap()
        XCTAssertTrue(app.buttons["empty-add-city"].exists)
    }
}
