import Foundation

actor WeatherRepository {
    private let store: CoreDataStack
    private let api: any WeatherProviding
    init(store: CoreDataStack, api: any WeatherProviding = WeatherAPIClient()) {
        self.store = store
        self.api = api
    }
    func cities() async throws -> [City] { try await store.cities() }
    func saveCities(_ cities: [City]) async throws { try await store.saveCities(cities) }
    func cached(for city: City) async throws -> Forecast? { try await store.forecast(for: city.id) }
    func refresh(for city: City) async throws -> Forecast {
        let forecast = try await api.forecast(for: city)
        try Task.checkCancellation()
        do { try await store.save(forecast, for: city.id) }
        catch { throw WeatherError.storage(error.localizedDescription) }
        return forecast
    }
}
