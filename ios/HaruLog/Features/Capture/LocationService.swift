import CoreLocation
import Foundation

/// One-shot location fetch + reverse geocoding into a display name
/// like "Seongsu-dong, Seoul". Callback is delivered on the main queue.
final class LocationService: NSObject, CLLocationManagerDelegate {
    var onPlaceResolved: ((String, CLLocationCoordinate2D) -> Void)?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPlace() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break // denied/restricted — UI keeps its fallback label
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let placemark = placemarks?.first
            let parts = [placemark?.subLocality, placemark?.locality].compactMap { $0 }
            let name = parts.isEmpty ? "Somewhere nice" : parts.joined(separator: ", ")
            DispatchQueue.main.async {
                self?.onPlaceResolved?(name, location.coordinate)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silent failure — UI keeps its fallback label.
    }
}
