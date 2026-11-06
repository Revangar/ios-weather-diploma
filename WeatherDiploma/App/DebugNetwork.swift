#if DEBUG
import Foundation

/// Explicit deterministic UI test transport. Never enabled by a normal launch or in Release.
final class DebugNetwork: URLProtocol, @unchecked Sendable {
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DebugNetwork.self]
        return URLSession(configuration: config)
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        if ProcessInfo.processInfo.arguments.contains("--offline") {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        do {
            let data: Data
            if url.host == "geocoding-api.open-meteo.com" {
                let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "name" }?.value ?? ""
                if query.lowercased().contains("zzzz") { data = Data("{}".utf8) }
                else {
                    let moscow = query.lowercased().contains("moscow") || query.lowercased().contains("моск")
                    let name = moscow ? "Москва" : "Берлин"
                    let id = moscow ? 524901 : 2950159
                    let zone = moscow ? "Europe/Moscow" : "Europe/Berlin"
                    let places: [[String: Any]] = [
                        ["id": id, "name": name, "latitude": moscow ? 55.75 : 52.52, "longitude": moscow ? 37.62 : 13.41,
                         "timezone": zone, "country": moscow ? "Россия" : "Германия", "admin1": name],
                        ["id": id + 1, "name": name, "latitude": 40.0, "longitude": -80.0, "timezone": "America/New_York", "country": "США"]
                    ]
                    data = try JSONSerialization.data(withJSONObject: ["results": places])
                }
            } else {
                let fixture = Bundle.main.url(forResource: "forecast-fixture", withExtension: "json")!
                var json = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as! [String: Any]
                if url.query?.contains("52.52") == true { json["timezone"] = "Europe/Berlin" }
                data = try JSONSerialization.data(withJSONObject: json)
            }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
#endif
