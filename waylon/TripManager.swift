//
//  TripManager.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import Foundation
import CoreLocation
import SwiftUI

class TripManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var trips: [Trip] = []
    @Published var currentDistance: Double = 0.0
    @Published var backgroundImage: UIImage? = nil
    @Published var userLocation: CLLocationCoordinate2D? = nil

    private var locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private let tripsKey = "savedTrips"
    private let backgroundKey = "savedBackground"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.startUpdatingLocation()
        loadTrips()
        loadBackground()
    }

    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTrip() {
        currentDistance = 0.0
        lastLocation = nil
    }

    func endTrip(withNotes notes: String, pay: String, start: CLLocationCoordinate2D?, end: CLLocationCoordinate2D?, route: [CLLocationCoordinate2D], startTime: Date, endTime: Date) {
        let newTrip = Trip(
            id: UUID(),
            date: startTime, // Store trip start time as 'date' for easier sorting/display
            distance: currentDistance,
            notes: notes,
            pay: pay,
            startCoordinate: start.map(CodableCoordinate.init),
            endCoordinate: end.map(CodableCoordinate.init),
            routeCoordinates: route.map(CodableCoordinate.init),
            startTime: startTime,
            endTime: endTime
        )
        trips.insert(newTrip, at: 0)
        saveTrips()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        if let last = lastLocation {
            let distanceDelta = newLocation.distance(from: last) / 1609.34
            currentDistance += distanceDelta
        }
        lastLocation = newLocation
        userLocation = newLocation.coordinate
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            print("Location authorized.")
        case .denied, .restricted:
            print("Location access denied or restricted.")
        default:
            break
        }
    }

    func updateTrip(_ updatedTrip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == updatedTrip.id }) {
            trips[index] = updatedTrip
            saveTrips()
        }
    }

    func deleteTrip(at offsets: IndexSet) {
        trips.remove(atOffsets: offsets)
        saveTrips()
    }

    private func saveTrips() {
        if let encoded = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(encoded, forKey: tripsKey)
        }
    }

    private func loadTrips() {
        if let savedData = UserDefaults.standard.data(forKey: tripsKey),
           let decoded = try? JSONDecoder().decode([Trip].self, from: savedData) {
            trips = decoded
        }
    }

    func setBackgroundImage(_ image: UIImage?) {
        backgroundImage = image
        saveBackground()
    }

    func removeBackgroundImage() {
        backgroundImage = nil
        saveBackground()
    }

    private func saveBackground() {
        guard let image = backgroundImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            UserDefaults.standard.removeObject(forKey: backgroundKey)
            return
        }
        UserDefaults.standard.set(imageData, forKey: backgroundKey)
    }

    private func loadBackground() {
        if let imageData = UserDefaults.standard.data(forKey: backgroundKey),
           let image = UIImage(data: imageData) {
            backgroundImage = image
        }
    }
}
