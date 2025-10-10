import CoreLocation
import SwiftUI

actor LocationService: NSObject, ObservableObject {
    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isTracking: Bool = false
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Only update every 10 meters
        
        // Optimize for automotive use
        if CLLocationManager.locationServicesEnabled() {
            locationManager.activityType = .automotiveNavigation
        }
    }
    
    func requestLocationPermission() async -> Bool {
        guard CLLocationManager.locationServicesEnabled() else { return false }
        
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .notDetermined:
            locationManager.requestWhenInUsePermission()
            return await waitForAuthorizationResponse()
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    private func waitForAuthorizationResponse() async -> Bool {
        // Implementation would wait for delegate callback
        // This is a simplified version
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    func startTracking() async {
        guard await requestLocationPermission() else { return }
        
        await MainActor.run {
            self.isTracking = true
        }
        
        locationManager.startUpdatingLocation()
        
        // For background tracking during trips
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func stopTracking() async {
        await MainActor.run {
            self.isTracking = false
        }
        
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
    }
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }
        
        return [placemark.name, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location.coordinate
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        Task { @MainActor in
            self.isTracking = false
        }
    }
}

enum LocationError: Error {
    case geocodingFailed
    case permissionDenied
    case serviceUnavailable
}