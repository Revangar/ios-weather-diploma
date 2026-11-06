import Foundation

struct GeocodingService: Sendable {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }
    func search(_ query: String) async throws -> [City] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { throw WeatherError.invalidQuery }
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [.init(name: "name", value: query), .init(name: "count", value: "10"),
                                 .init(name: "language", value: "ru"), .init(name: "format", value: "json")]
        let data = try await HTTPClient.data(from: components.url!, session: session)
        let cities = try await Task.detached {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(GeocodingDTO.self, from: data).results?.map(\.city) ?? []
        }.value
        guard !cities.isEmpty else { throw WeatherError.emptySearch }
        return cities
    }
}

struct GeocodingDTO: Decodable, Sendable {
    let results: [Place]?
    struct Place: Decodable, Sendable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let timezone: String?
        let country: String?
        let admin1: String?
        var city: City {
            City(id: String(id), name: name, country: country ?? "", region: admin1 ?? "",
                 latitude: latitude, longitude: longitude, timezone: timezone ?? "GMT")
        }
    }
}
