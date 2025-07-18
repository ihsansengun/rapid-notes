import CoreLocation
import Foundation

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var currentPlacemark: CLPlacemark?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocationName: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        #if os(iOS)
        locationManager.requestWhenInUseAuthorization()
        #elseif os(macOS)
        locationManager.requestAlwaysAuthorization()
        #endif
        
        // Request location immediately if authorized
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            requestLocation()
        }
    }
    
    func requestLocation() {
        #if os(iOS)
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        #elseif os(macOS)
        guard authorizationStatus == .authorizedAlways else {
            return
        }
        #endif
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        currentLocation = location
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.currentPlacemark = placemarks?.first
                self?.currentLocationName = self?.getLocationName()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        // Request location when authorization is granted
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            requestLocation()
        }
    }
    
    func getLocationName() -> String {
        guard let placemark = currentPlacemark else { return "Unknown Location" }
        
        var locationComponents: [String] = []
        
        if let name = placemark.name {
            locationComponents.append(name)
        }
        if let locality = placemark.locality {
            locationComponents.append(locality)
        }
        if let country = placemark.country {
            locationComponents.append(country)
        }
        
        return locationComponents.joined(separator: ", ")
    }
}