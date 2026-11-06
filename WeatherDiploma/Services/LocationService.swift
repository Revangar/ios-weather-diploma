import CoreLocation

@MainActor
final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    private var continuation: CheckedContinuation<City, Error>?
    private var requestID: UUID?
    private var timeout: Task<Void, Never>?
    private var geocoding: Task<Void, Never>?
    private var geocoder: CLGeocoder?
    private var lastLocation: CLLocation?

    func locate() async throws -> City {
        try Task.checkCancellation()
        guard requestID == nil else { throw CLError(.locationUnknown) }
        let id = UUID()
        requestID = id
        let manager = CLLocationManager()
        self.manager = manager
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                switch manager.authorizationStatus {
                case .notDetermined: manager.requestWhenInUseAuthorization()
                case .authorizedAlways, .authorizedWhenInUse: requestLocation(id)
                default: finish(.failure(CLError(.denied)), id: id)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError()), id: id) }
        }
    }
    private func requestLocation(_ id: UUID) {
        guard requestID == id, timeout == nil else { return }
        manager?.requestLocation()
        // Waiting for a human decision in the system alert is not a GPS timeout.
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(25)) } catch { return }
            guard let self, self.requestID == id else { return }
            if let location = self.lastLocation { self.finish(.success(self.city(location)), id: id) }
            else { self.finish(.failure(CLError(.locationUnknown)), id: id) }
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager === self.manager, let id = requestID else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: requestLocation(id)
        case .denied, .restricted: finish(.failure(CLError(.denied)), id: id)
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard manager === self.manager, let id = requestID, geocoding == nil else { return }
        guard let location = locations.last else { finish(.failure(CLError(.locationUnknown)), id: id); return }
        lastLocation = location
        let geocoder = CLGeocoder()
        self.geocoder = geocoder
        geocoding = Task { [weak self] in
            let placemark = try? await geocoder.reverseGeocodeLocation(location).first
            guard let self, !Task.isCancelled, self.requestID == id else { return }
            self.finish(.success(self.city(location, placemark: placemark)), id: id)
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard manager === self.manager, let id = requestID else { return }
        finish(.failure(error), id: id)
    }
    private func city(_ location: CLLocation, placemark: CLPlacemark? = nil) -> City {
        let coordinate = location.coordinate
        return City(id: String(format: "geo:%.3f:%.3f", coordinate.latitude, coordinate.longitude),
                    name: placemark?.locality ?? "Текущее местоположение", country: placemark?.country ?? "",
                    region: placemark?.administrativeArea ?? "", latitude: coordinate.latitude,
                    longitude: coordinate.longitude, timezone: placemark?.timeZone?.identifier ?? "GMT")
    }
    private func finish(_ result: Result<City, Error>, id: UUID) {
        guard requestID == id else { return }
        requestID = nil
        let pending = continuation
        continuation = nil
        manager?.delegate = nil
        manager?.stopUpdatingLocation()
        manager = nil
        timeout?.cancel(); timeout = nil
        geocoding?.cancel(); geocoding = nil
        geocoder?.cancelGeocode(); geocoder = nil
        lastLocation = nil
        pending?.resume(with: result)
    }
}
