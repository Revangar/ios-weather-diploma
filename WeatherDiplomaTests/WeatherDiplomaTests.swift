import XCTest
import UIKit
@testable import WeatherDiploma

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct State: Sendable {
        var data = Data()
        var status = 200
        var error: URLError?
        var url: URL?
    }
    private static let lock = NSLock()
    nonisolated(unsafe) private static var state = State()
    static func configure(data: Data = Data(), status: Int = 200, error: URLError? = nil) {
        lock.withLock { state = State(data: data, status: status, error: error) }
    }
    static var lastURL: URL? { lock.withLock { state.url } }
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = Self.lock.withLock { Self.state.url = request.url; return Self.state }
        if let error = response.error { client?.urlProtocol(self, didFailWithError: error); return }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
final class WeatherDiplomaTests: XCTestCase {
    private let moscow = City(id: "524901", name: "Москва", country: "Россия", region: "Москва",
                              latitude: 55.75, longitude: 37.62, timezone: "Europe/Moscow")
    private func fixture() throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "forecast-fixture", withExtension: "json")))
    }
    private func forecast() throws -> Forecast {
        let decoder = JSONDecoder()
        return try decoder.decode(ForecastDTO.self, from: fixture()).normalized()
    }
    func testRealJSONDTOAnd24HourWindow() throws {
        let forecast = try forecast()
        XCTAssertEqual(forecast.days.count, 7)
        XCTAssertEqual(forecast.hours.count, 168)
        XCTAssertEqual(forecast.next24.count, 24)
        XCTAssertNotNil(forecast.current.temperature)
        XCTAssertNotNil(forecast.days[0].daylight)
        XCTAssertEqual(forecast.next24[1].time.timeIntervalSince(forecast.next24[0].time), 3600)
        XCTAssertEqual(forecast.hours(on: forecast.days[0]).count, 24)
    }
    func testNullWeatherIsMissingRatherThanZero() throws {
        var json = try JSONSerialization.jsonObject(with: fixture()) as! [String: Any]
        var current = json["current"] as! [String: Any]
        current["temperature_2m"] = NSNull()
        json["current"] = current
        let decoder = JSONDecoder()
        let value = try decoder.decode(ForecastDTO.self, from: JSONSerialization.data(withJSONObject: json)).normalized()
        XCTAssertNil(value.current.temperature)
        XCTAssertEqual(WeatherSettings().temperature(value.current.temperature), "—")
    }
    func testMalformedParallelArraysAreRejected() throws {
        var json = try JSONSerialization.jsonObject(with: fixture()) as! [String: Any]
        var hourly = json["hourly"] as! [String: Any]
        hourly["temperature_2m"] = [1.0]
        json["hourly"] = hourly
        let decoder = JSONDecoder()
        let dto = try decoder.decode(ForecastDTO.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try dto.normalized()) { XCTAssertEqual($0 as? WeatherError, .invalidData) }
    }
    func testForecastRequestContractViaURLProtocol() async throws {
        StubURLProtocol.configure(data: try fixture())
        let value = try await WeatherAPIClient(session: StubURLProtocol.session()).forecast(for: moscow)
        XCTAssertEqual(value.days.count, 7)
        let components = URLComponents(url: try XCTUnwrap(StubURLProtocol.lastURL), resolvingAgainstBaseURL: false)!
        let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query["timezone"], "auto")
        XCTAssertEqual(query["timeformat"], "unixtime")
        XCTAssertEqual(query["forecast_days"], "7")
        XCTAssertEqual(query["wind_speed_unit"], "ms")
    }
    func testGeocodingUnicodeAndAmbiguousCities() async throws {
        let data = Data(#"{"results":[{"id":1,"name":"Москва","latitude":55.75,"longitude":37.62,"timezone":"Europe/Moscow","country":"Россия"},{"id":2,"name":"Москва","latitude":46.73,"longitude":-117,"timezone":"America/Los_Angeles","country":"США"}]}"#.utf8)
        StubURLProtocol.configure(data: data)
        let cities = try await GeocodingService(session: StubURLProtocol.session()).search("  Москва  ")
        XCTAssertEqual(cities.count, 2)
        XCTAssertFalse(cities[0].matches(cities[1]))
        let components = URLComponents(url: try XCTUnwrap(StubURLProtocol.lastURL), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first { $0.name == "name" }?.value, "Москва")
    }
    func testGeocodingEmptyResult() async throws {
        StubURLProtocol.configure(data: Data("{}".utf8))
        do { _ = try await GeocodingService(session: StubURLProtocol.session()).search("zzzz"); XCTFail("Expected no results") }
        catch { XCTAssertEqual(error as? WeatherError, .emptySearch) }
    }
    func testGeocodingInvalidQueryHasNoRequest() async throws {
        StubURLProtocol.configure()
        do { _ = try await GeocodingService(session: StubURLProtocol.session()).search(" "); XCTFail("Expected invalid query") }
        catch { XCTAssertEqual(error as? WeatherError, .invalidQuery) }
        XCTAssertNil(StubURLProtocol.lastURL)
    }
    func testHTTPErrorAndOfflinePropagation() async throws {
        let service = GeocodingService(session: StubURLProtocol.session())
        StubURLProtocol.configure(status: 429)
        do { _ = try await service.search("Berlin"); XCTFail("Expected HTTP failure") }
        catch { XCTAssertEqual(error as? WeatherError, .http(429)) }
        StubURLProtocol.configure(error: URLError(.notConnectedToInternet))
        do { _ = try await service.search("Berlin"); XCTFail("Expected offline failure") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
    }
    func testCoreDataSQLiteReopenAndCityIsolation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Weather.sqlite")
        let store = try await CoreDataStack.make(storeURL: url)
        let original = try forecast()
        try await store.saveCities([moscow])
        try await store.save(original, for: moscow.id)
        let reopened = try await CoreDataStack.make(storeURL: url)
        let loadedCities = try await reopened.cities()
        let cached = try await reopened.forecast(for: moscow.id)
        let other = try await reopened.forecast(for: "another-city")
        XCTAssertEqual(loadedCities, [moscow])
        XCTAssertEqual(cached, original)
        XCTAssertNil(other)
        try await reopened.saveCities([])
        let removed = try await reopened.forecast(for: moscow.id)
        XCTAssertNil(removed)
    }
    func testOfflineRefreshPreservesFullCache() async throws {
        let store = try await CoreDataStack.make(inMemory: true)
        let original = try forecast()
        try await store.saveCities([moscow])
        try await store.save(original, for: moscow.id)
        StubURLProtocol.configure(error: URLError(.notConnectedToInternet))
        let repository = WeatherRepository(store: store, api: WeatherAPIClient(session: StubURLProtocol.session()))
        do { _ = try await repository.refresh(for: moscow); XCTFail("Expected offline failure") } catch { }
        let cached = try await repository.cached(for: moscow)
        XCTAssertEqual(cached, original)
    }
    func testTimezonesAndRepeatedDSTHour() throws {
        let parser = ISO8601DateFormatter()
        let first = try XCTUnwrap(parser.date(from: "2026-10-25T00:30:00Z"))
        let second = try XCTUnwrap(parser.date(from: "2026-10-25T01:30:00Z"))
        XCTAssertEqual(WeatherFormat.date(first, zone: "Europe/Berlin", format: "HH:mm ZZZZZ"), "02:30 +02:00")
        XCTAssertEqual(WeatherFormat.date(second, zone: "Europe/Berlin", format: "HH:mm ZZZZZ"), "02:30 +01:00")
        XCTAssertEqual(WeatherFormat.date(first, zone: "America/Los_Angeles", format: "dd.MM HH:mm"), "24.10 17:30")
        XCTAssertEqual(WeatherFormat.date(first, zone: "Asia/Tokyo", format: "dd.MM HH:mm"), "25.10 09:30")
    }
    func testSettingsPersistenceConversionsAndDuplicateCoordinates() throws {
        let name = "WeatherTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = WeatherSettings(fahrenheit: true, miles: true, twelveHour: true)
        settings.save(defaults)
        XCTAssertEqual(WeatherSettings.load(defaults), settings)
        XCTAssertEqual(settings.temperature(0), "32°F")
        XCTAssertEqual(WeatherFormat.duration(36061), "10 ч 1 мин")
        let same = City(id: "geo", name: "Current", country: "", region: "", latitude: 55.751, longitude: 37.621, timezone: "Europe/Moscow")
        XCTAssertTrue(moscow.matches(same))
    }
    func testWeatherHeaderFitsWhenPageReceivesAndChangesItsWidth() async throws {
        let store = try await CoreDataStack.make(inMemory: true)
        let repository = WeatherRepository(store: store, api: WeatherAPIClient())
        let name = "WeatherHeaderGeometry.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let page = WeatherViewController(city: moscow, repository: repository, defaults: defaults)
        page.loadViewIfNeeded()
        for width: CGFloat in [0, 760, 320, 600] {
            page.view.frame = CGRect(x: 0, y: 0, width: width, height: 800)
            page.view.setNeedsLayout()
            page.view.layoutIfNeeded()
            guard width > 0 else { continue }
            let header = try XCTUnwrap(page.tableView.tableHeaderView)
            XCTAssertEqual(header.frame.width, width, accuracy: 0.5)
            XCTAssertGreaterThan(header.frame.height, 24)
            XCTAssertTrue(header.frame.height.isFinite)
        }
    }
    func testReducedAccuracyLocationDoesNotDuplicateCity() {
        let approximate = City(id: "geo:55.731:37.636", name: "Москва", country: "Россия", region: "Москва",
                               latitude: 55.7307958, longitude: 37.6361917, timezone: "Europe/Moscow")
        XCTAssertTrue(moscow.matches(approximate))
        let other = City(id: "manual-different", name: "Москва", country: "Россия", region: "Москва",
                         latitude: 55.7307958, longitude: 37.6361917, timezone: "Europe/Moscow")
        XCTAssertFalse(moscow.matches(other), "Distinct manual results must keep their geographic identity")
        let far = City(id: "geo:50:37", name: "Москва", country: "Россия", region: "Москва",
                       latitude: 50, longitude: 37, timezone: "Europe/Moscow")
        XCTAssertFalse(moscow.matches(far))
    }
    func testCancelledRefreshCannotOverwriteCache() async throws {
        let store = try await CoreDataStack.make(inMemory: true)
        try await store.saveCities([moscow])
        let original = try forecast()
        try await store.save(original, for: moscow.id)
        let replacement = Forecast(timezone: original.timezone, fetchedAt: original.fetchedAt.addingTimeInterval(3600),
                                   current: original.current, hours: original.hours, days: original.days)
        let api = GatedWeatherProvider(response: replacement)
        let repository = WeatherRepository(store: store, api: api)
        let city = moscow
        let request = Task { try await repository.refresh(for: city) }
        await api.waitForStart()
        request.cancel()
        await api.complete() // A non-cooperative provider returns even after cancellation.
        do { _ = try await request.value; XCTFail("Cancelled response must be rejected") }
        catch { XCTAssertTrue(error is CancellationError) }
        let cached = try await store.forecast(for: city.id)
        XCTAssertEqual(cached, original)
    }
    func testLateResponseCannotRecreateDeletedCity() async throws {
        let store = try await CoreDataStack.make(inMemory: true)
        try await store.saveCities([moscow])
        let api = GatedWeatherProvider(response: try forecast())
        let repository = WeatherRepository(store: store, api: api)
        let city = moscow
        let request = Task { try await repository.refresh(for: city) }
        await api.waitForStart()
        try await repository.saveCities([])
        await api.complete()
        _ = try await request.value
        let cached = try await store.forecast(for: city.id)
        let cities = try await store.cities()
        XCTAssertNil(cached, "A late network response must not recreate deleted forecast records")
        XCTAssertTrue(cities.isEmpty)
    }
    func testHourlyChartsCellAndDetailRowsCoexist() throws {
        let value = try forecast()

        let hourly = ForecastDetailViewController(
            city: moscow, forecast: value, settings: WeatherSettings()
        )
        hourly.loadViewIfNeeded()

        XCTAssertEqual(hourly.numberOfSections(in: hourly.tableView), 2)
        XCTAssertEqual(hourly.tableView(hourly.tableView, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(
            hourly.tableView(hourly.tableView, numberOfRowsInSection: 1),
            value.next24.count
        )

        let chartCell = hourly.tableView(
            hourly.tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        )
        XCTAssertEqual(chartCell.accessibilityIdentifier, "forecast-charts")
        XCTAssertNotNil(chartCell.contentConfiguration)

        let daily = ForecastDetailViewController(
            city: moscow, forecast: value, settings: WeatherSettings(), day: 0
        )
        daily.loadViewIfNeeded()
        XCTAssertEqual(daily.numberOfSections(in: daily.tableView), 2)
        XCTAssertEqual(
            daily.tableView(daily.tableView, numberOfRowsInSection: 1),
            value.hours(on: value.days[0]).count + 3
        )
    }

    func testForecastNavigationControllersAreReleased() async throws {
        let value = try forecast()
        weak var weakDetail: ForecastDetailViewController?
        weak var weakContainer: ReadableContainerViewController?
        autoreleasepool {
            let detail = ForecastDetailViewController(city: moscow, forecast: value, settings: .init(), day: 0)
            let container = ReadableContainerViewController(detail)
            container.loadViewIfNeeded()
            container.view.frame = CGRect(x: 0, y: 0, width: 800, height: 1000)
            container.view.layoutIfNeeded()
            weakDetail = detail
            weakContainer = container
        }
        await Task.yield()
        XCTAssertNil(weakContainer)
        XCTAssertNil(weakDetail)
    }

}


private actor GatedWeatherProvider: WeatherProviding {
    private let response: Forecast
    private var request: CheckedContinuation<Forecast, Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    init(response: Forecast) { self.response = response }
    func forecast(for city: City) async throws -> Forecast {
        await withCheckedContinuation { continuation in
            request = continuation
            startWaiters.forEach { $0.resume() }
            startWaiters.removeAll()
        }
    }
    func waitForStart() async {
        if request != nil { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }
    func complete() { request?.resume(returning: response); request = nil }
}
