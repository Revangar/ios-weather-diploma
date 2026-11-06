import Foundation

protocol WeatherProviding: Sendable {
    func forecast(for city: City) async throws -> Forecast
}

struct WeatherAPIClient: WeatherProviding {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func forecast(for city: City) async throws -> Forecast {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(city.latitude)),
            .init(name: "longitude", value: String(city.longitude)),
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"),
            .init(name: "wind_speed_unit", value: "ms"),
            .init(name: "forecast_days", value: "7"),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"),
            .init(name: "hourly", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,is_day"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,daylight_duration,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max")
        ]
        let data = try await HTTPClient.data(from: components.url!, session: session)
        return try await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            return try decoder.decode(ForecastDTO.self, from: data).normalized()
        }.value
    }
}

enum HTTPClient {
    static func data(from url: URL, session: URLSession) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw WeatherError.invalidData }
        guard (200..<300).contains(response.statusCode) else { throw WeatherError.http(response.statusCode) }
        return data
    }
}

struct ForecastDTO: Decodable, Sendable {
    let timezone: String
    let current: Current
    let hourly: Hourly
    let daily: Daily
    struct Current: Decodable, Sendable {
        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case isDay = "is_day"
            case precipitation
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
        }
        let time: Double
        let temperature2m: Double?
        let relativeHumidity2m: Double?
        let apparentTemperature: Double?
        let isDay: Int?
        let precipitation: Double?
        let weatherCode: Int?
        let windSpeed10m: Double?
    }
    struct Hourly: Decodable, Sendable {
        enum CodingKeys: String, CodingKey {
            case time, precipitation
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case precipitationProbability = "precipitation_probability"
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case windSpeed10m = "wind_speed_10m"
            case windDirection10m = "wind_direction_10m"
            case isDay = "is_day"
        }
        let time: [Double]
        let temperature2m: [Double?]
        let relativeHumidity2m: [Double?]
        let apparentTemperature: [Double?]
        let precipitationProbability: [Double?]
        let precipitation: [Double?]
        let weatherCode: [Int?]
        let cloudCover: [Double?]
        let windSpeed10m: [Double?]
        let windDirection10m: [Double?]
        let isDay: [Int?]
    }
    struct Daily: Decodable, Sendable {
        enum CodingKeys: String, CodingKey {
            case time, sunrise, sunset
            case weatherCode = "weather_code"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case daylightDuration = "daylight_duration"
            case uvIndexMax = "uv_index_max"
            case precipitationSum = "precipitation_sum"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case windSpeed10mMax = "wind_speed_10m_max"
        }
        let time: [Double]
        let weatherCode: [Int?]
        let temperature2mMax: [Double?]
        let temperature2mMin: [Double?]
        let sunrise: [Double?]
        let sunset: [Double?]
        let daylightDuration: [Double?]
        let uvIndexMax: [Double?]
        let precipitationSum: [Double?]
        let precipitationProbabilityMax: [Double?]
        let windSpeed10mMax: [Double?]
    }

    func normalized(now: Date = Date()) throws -> Forecast {
        let h = hourly
        let d = daily
        guard TimeZone(identifier: timezone) != nil, !h.time.isEmpty, d.time.count == 7,
              [h.temperature2m.count, h.relativeHumidity2m.count, h.apparentTemperature.count,
               h.precipitationProbability.count, h.precipitation.count, h.weatherCode.count,
               h.cloudCover.count, h.windSpeed10m.count, h.windDirection10m.count, h.isDay.count]
                .allSatisfy({ $0 == h.time.count }),
              [d.weatherCode.count, d.temperature2mMax.count, d.temperature2mMin.count, d.sunrise.count,
               d.sunset.count, d.daylightDuration.count, d.uvIndexMax.count, d.precipitationSum.count,
               d.precipitationProbabilityMax.count, d.windSpeed10mMax.count].allSatisfy({ $0 == d.time.count })
        else { throw WeatherError.invalidData }
        return Forecast(timezone: timezone, fetchedAt: now,
                        current: .init(time: Date(timeIntervalSince1970: current.time), temperature: current.temperature2m,
                                       feelsLike: current.apparentTemperature, humidity: current.relativeHumidity2m,
                                       precipitation: current.precipitation, wind: current.windSpeed10m,
                                       code: current.weatherCode, isDay: current.isDay == 1),
                        hours: h.time.indices.map { i in
                            .init(time: Date(timeIntervalSince1970: h.time[i]), temperature: h.temperature2m[i],
                                  feelsLike: h.apparentTemperature[i], humidity: h.relativeHumidity2m[i],
                                  precipitation: h.precipitation[i], probability: h.precipitationProbability[i],
                                  wind: h.windSpeed10m[i], direction: h.windDirection10m[i], cloud: h.cloudCover[i],
                                  code: h.weatherCode[i], isDay: h.isDay[i] == 1)
                        }, days: d.time.indices.map { i in
                            .init(time: Date(timeIntervalSince1970: d.time[i]), low: d.temperature2mMin[i],
                                  high: d.temperature2mMax[i], code: d.weatherCode[i], precipitation: d.precipitationSum[i],
                                  probability: d.precipitationProbabilityMax[i], wind: d.windSpeed10mMax[i],
                                  sunrise: d.sunrise[i].flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil },
                                  sunset: d.sunset[i].flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil },
                                  daylight: d.daylightDuration[i], uv: d.uvIndexMax[i])
                        })
    }
}
