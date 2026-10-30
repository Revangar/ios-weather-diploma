import CoreLocation

@MainActor
final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<City, Error>?
    private var timeout: Task<Void, Never>?
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }
    func locate() async throws -> City {
        guard continuation == nil else { throw CLError(.locationUnknown) }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined: manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
            default: finish(.failure(CLError(.denied)))
            }
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(25)) } catch { return }
                self?.finish(.failure(CLError(.locationUnknown)))
            }
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(.failure(CLError(.denied)))
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { finish(.failure(CLError(.locationUnknown))); return }
        Task {
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            let coordinate = location.coordinate
            let city = City(id: String(format: "geo:%.3f:%.3f", coordinate.latitude, coordinate.longitude),
                            name: placemark?.locality ?? "Текущее местоположение", country: placemark?.country ?? "",
                            region: placemark?.administrativeArea ?? "", latitude: coordinate.latitude,
                            longitude: coordinate.longitude, timezone: placemark?.timeZone?.identifier ?? "GMT")
            finish(.success(city))
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(.failure(error)) }
    private func finish(_ result: Result<City, Error>) {
        timeout?.cancel()
        timeout = nil
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }
}
