import Foundation

struct City: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let country: String
    let region: String
    let latitude: Double
    let longitude: Double
    let timezone: String
    var subtitle: String { [region, country].filter { !$0.isEmpty }.joined(separator: ", ") }
    func matches(_ other: City) -> Bool {
        id == other.id || (abs(latitude - other.latitude) < 0.01 && abs(longitude - other.longitude) < 0.01)
    }
}

struct CurrentWeather: Codable, Sendable, Equatable {
    let time: Date
    let temperature: Double?
    let feelsLike: Double?
    let humidity: Double?
    let precipitation: Double?
    let wind: Double?
    let code: Int?
    let isDay: Bool
}

struct HourWeather: Codable, Sendable, Equatable {
    let time: Date
    let temperature: Double?
    let feelsLike: Double?
    let humidity: Double?
    let precipitation: Double?
    let probability: Double?
    let wind: Double?
    let direction: Double?
    let cloud: Double?
    let code: Int?
    let isDay: Bool
}

struct DayWeather: Codable, Sendable, Equatable {
    let time: Date
    let low: Double?
    let high: Double?
    let code: Int?
    let precipitation: Double?
    let probability: Double?
    let wind: Double?
    let sunrise: Date?
    let sunset: Date?
    let daylight: Double?
    let uv: Double?
}

struct Forecast: Codable, Sendable, Equatable {
    let timezone: String
    let fetchedAt: Date
    let current: CurrentWeather
    let hours: [HourWeather]
    let days: [DayWeather]
    var next24: [HourWeather] {
        let start = floor(current.time.timeIntervalSince1970 / 3600) * 3600
        return Array(hours.filter { $0.time.timeIntervalSince1970 >= start }.prefix(24))
    }
    var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 3600 }
    func hours(on day: DayWeather) -> [HourWeather] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .gmt
        return hours.filter { calendar.isDate($0.time, inSameDayAs: day.time) }
    }
}

enum WeatherError: LocalizedError, Equatable {
    case invalidData, http(Int), emptySearch, invalidQuery, storage(String)
    var errorDescription: String? {
        switch self {
        case .invalidData: "Сервис прислал неполные данные. Попробуйте обновить позже."
        case .http(let status): "Сервис временно недоступен (HTTP \(status)). Повторите запрос."
        case .emptySearch: "Город не найден. Проверьте название или укажите страну."
        case .invalidQuery: "Введите не менее двух букв названия города."
        case .storage(let message): "Не удалось сохранить данные: \(message)"
        }
    }
}

enum WeatherCode {
    static func description(_ code: Int?) -> String {
        guard let code else { return "Нет данных о состоянии" }
        return switch code {
        case 0: "Ясно"
        case 1: "Преимущественно ясно"
        case 2: "Переменная облачность"
        case 3: "Пасмурно"
        case 45, 48: "Туман"
        case 51...57: "Морось"
        case 61...67: "Дождь"
        case 71...77, 85, 86: "Снег"
        case 80...82: "Ливни"
        case 95...99: "Гроза"
        default: "Нет данных о состоянии"
        }
    }
    static func symbol(_ code: Int?, isDay: Bool = true) -> String {
        guard let code else { return "questionmark.circle" }
        return switch code {
        case 0, 1: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "questionmark.circle"
        }
    }
}

struct WeatherSettings: Sendable, Equatable {
    var fahrenheit = false
    var miles = false
    var twelveHour = false
    static func load(_ defaults: UserDefaults = .standard) -> WeatherSettings {
        .init(fahrenheit: defaults.bool(forKey: "fahrenheit"), miles: defaults.bool(forKey: "miles"),
              twelveHour: defaults.bool(forKey: "twelveHour"))
    }
    func save(_ defaults: UserDefaults = .standard) {
        defaults.set(fahrenheit, forKey: "fahrenheit")
        defaults.set(miles, forKey: "miles")
        defaults.set(twelveHour, forKey: "twelveHour")
    }
    func temperature(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((fahrenheit ? value * 1.8 + 32 : value).rounded()))°\(fahrenheit ? "F" : "C")"
    }
    func wind(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f %@", miles ? value * 2.236936 : value, miles ? "миль/ч" : "м/с")
    }
    func time(_ date: Date, zone: String) -> String {
        WeatherFormat.date(date, zone: zone, format: twelveHour ? "h:mm a" : "HH:mm")
    }
}

enum WeatherFormat {
    static func date(_ date: Date, zone: String, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(identifier: zone) ?? .gmt
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    static func number(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%@", value, suffix)
    }
    static func rain(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f мм", value)
    }
    static func duration(_ seconds: Double?) -> String {
        guard let seconds else { return "—" }
        let minutes = Int(seconds / 60)
        return "\(minutes / 60) ч \(minutes % 60) мин"
    }
}
