//
//  TripManager.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import Foundation
import CoreLocation
import SwiftUI
import UIKit

struct FavoriteAddress: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var address: String
    var coordinate: CodableCoordinate?
    
    init(id: UUID = UUID(), name: String, address: String, coordinate: CodableCoordinate? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
    }
}

class TripManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // REQUIRED: Add these keys to Info.plist:
    // NSLocationAlwaysAndWhenInUseUsageDescription
    // NSLocationWhenInUseUsageDescription
    // UIBackgroundModes (Array, include 'location')

    @Published var trips: [Trip] = []
    @Published var currentDistance: Double = 0.0
    @Published var backgroundImage: UIImage? = nil
    @Published var userLocation: CLLocationCoordinate2D? = nil
    @Published var favoriteAddresses: [FavoriteAddress] = []
    
    private var locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private let tripsKey = "savedTrips"
    private let backgroundKey = "savedBackground"
    private let currentTripKey = "ongoingTripState"
    private let favoritesKey = "favoriteAddressesKey"
    
    private var currentTripStartLocation: CLLocationCoordinate2D?
    private var currentTripStartTime: Date? = nil
    private var currentRoute: [CLLocationCoordinate2D] = []

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()
        loadTrips()
        loadBackground()
        loadFavoriteAddresses()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackgrounding), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackgrounding), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        restoreOngoingTripIfNeeded()
    }
    
    @objc private func handleAppBackgrounding() {
        if currentTripStartLocation != nil, let start = currentTripStartLocation, let startTime = currentTripStartTime {
            // Save partial trip state to UserDefaults
            let tripState = OngoingTripState(startLocation: start, startTime: startTime, route: currentRoute, distance: currentDistance)
            if let data = try? JSONEncoder().encode(tripState) {
                UserDefaults.standard.set(data, forKey: currentTripKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: currentTripKey)
        }
    }
    
    private struct OngoingTripState: Codable {
        let startLocation: CodableCoordinate
        let startTime: Date
        let route: [CodableCoordinate]
        let distance: Double
        init(startLocation: CLLocationCoordinate2D, startTime: Date, route: [CLLocationCoordinate2D], distance: Double) {
            self.startLocation = CodableCoordinate(from: startLocation)
            self.startTime = startTime
            self.route = route.map { CodableCoordinate(from: $0) }
            self.distance = distance
        }
    }
    
    private func restoreOngoingTripIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: currentTripKey),
              let state = try? JSONDecoder().decode(OngoingTripState.self, from: data) else { return }
        let start = state.startLocation.clCoordinate
        self.currentTripStartLocation = start
        self.currentTripStartTime = state.startTime
        var recoveredRoute = state.route.map { $0.clCoordinate }
        print("[TripRecovery] Initial recoveredRoute: \(recoveredRoute)")
        let endpoint: CLLocationCoordinate2D? = userLocation ?? recoveredRoute.last
        if recoveredRoute.isEmpty {
            if let endpoint = endpoint, endpoint != start {
                recoveredRoute = [start, endpoint]
            } else {
                // If no other endpoint, duplicate start
                recoveredRoute = [start, start]
            }
        } else if recoveredRoute.count == 1 {
            if let endpoint = endpoint, endpoint != recoveredRoute[0] {
                recoveredRoute.append(endpoint)
            } else {
                // Duplicate the single point
                recoveredRoute.append(recoveredRoute[0])
            }
        } else {
            // If the last isn't the endpoint, append it
            if let endpoint = endpoint, recoveredRoute.last != endpoint {
                recoveredRoute.append(endpoint)
            }
        }
        print("[TripRecovery] Final route used: \(recoveredRoute)")
        
        // Calculate total distance in miles for the recovered route
        var totalDistanceMiles = 0.0
        for i in 1..<recoveredRoute.count {
            let prev = recoveredRoute[i-1]
            let curr = recoveredRoute[i]
            let prevLoc = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
            let currLoc = CLLocation(latitude: curr.latitude, longitude: curr.longitude)
            totalDistanceMiles += currLoc.distance(from: prevLoc) / 1609.34
        }
        self.currentDistance = totalDistanceMiles
        print("[TripRecovery] Calculated distance (miles): \(totalDistanceMiles)")
        
        self.endTrip(withNotes: "", pay: "", start: start, end: endpoint, route: recoveredRoute, isRecovered: true)
        UserDefaults.standard.removeObject(forKey: currentTripKey)
    }

    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTrip() {
        currentDistance = 0.0
        lastLocation = nil
        currentTripStartLocation = userLocation
        currentTripStartTime = Date()
        currentRoute = []
        UserDefaults.standard.removeObject(forKey: currentTripKey)
    }

    /// Ends the current trip, saving it with the provided details.
    /// - Parameters:
    ///   - notes: Notes about the trip.
    ///   - pay: Payment info related to the trip.
    ///   - start: Optional start coordinate; defaults to trip start location.
    ///   - end: Optional end coordinate; defaults to current user location.
    ///   - route: The route coordinates of the trip.
    ///   - audioNotes: Optional audio notes URLs.
    ///   - photoURLs: Optional photo URLs.
    ///   - reason: Optional reason for trip ending.
    ///   - isRecovered: Indicates if the trip was recovered after app termination. Defaults to false.
    func endTrip(withNotes notes: String, pay: String, start: CLLocationCoordinate2D? = nil, end: CLLocationCoordinate2D? = nil, route: [CLLocationCoordinate2D]? = nil, audioNotes: [URL] = [], photoURLs: [URL] = [], reason: String = "", isRecovered: Bool = false) {
        let actualRoute = route ?? currentRoute

        var paddedRoute = actualRoute
        if paddedRoute.isEmpty {
            if let s = start ?? currentTripStartLocation, let e = end ?? userLocation, s != e {
                paddedRoute = [s, e]
            } else if let s = start ?? currentTripStartLocation {
                paddedRoute = [s, s]
            }
        } else if paddedRoute.count == 1 {
            // If only one point, duplicate for polyline
            paddedRoute.append(paddedRoute[0])
        }
        
        print("[TripSaveDebug] Saving trip with \(paddedRoute.count) points:")
        for (i, coord) in paddedRoute.enumerated() {
            print("  [\(i)] \(coord.latitude), \(coord.longitude)")
        }

        let tripStartTime = currentTripStartTime ?? Date()
        let tripEndTime = Date()
        let actualStart = start ?? currentTripStartLocation
        let actualEnd = end ?? userLocation
        let newTrip = Trip(
            id: UUID(),
            date: tripStartTime, // Store trip start time as 'date' for easier sorting/display
            distance: currentDistance,
            notes: notes,
            pay: pay,
            audioNotes: audioNotes,
            photoURLs: photoURLs,
            startCoordinate: actualStart.map { CodableCoordinate(from: $0) },
            endCoordinate: actualEnd.map { CodableCoordinate(from: $0) },
            routeCoordinates: paddedRoute.map { CodableCoordinate(from: $0) },
            startTime: tripStartTime,
            endTime: tripEndTime,
            reason: reason,
            isRecovered: isRecovered
        )
        trips.insert(newTrip, at: 0)
        saveTrips()
        currentTripStartLocation = nil
        currentTripStartTime = nil
        currentRoute = []
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        if let last = lastLocation {
            let distanceDelta = newLocation.distance(from: last) / 1609.34
            currentDistance += distanceDelta
        }
        lastLocation = newLocation
        userLocation = newLocation.coordinate

        if currentTripStartLocation != nil {
            currentRoute.append(newLocation.coordinate)
            print("[RouteDebug] Logged coordinate: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude). Total route points: \(currentRoute.count)")
        }
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
        if manager.authorizationStatus != .authorizedAlways {
            print("Warning: Always authorization is required for background location updates.")
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
    
    func addFavoriteAddress(_ favorite: FavoriteAddress) {
        favoriteAddresses.append(favorite)
        saveFavoriteAddresses()
    }
    
    func removeFavoriteAddress(at offsets: IndexSet) {
        favoriteAddresses.remove(atOffsets: offsets)
        saveFavoriteAddresses()
    }
    
    private func saveFavoriteAddresses() {
        if let encoded = try? JSONEncoder().encode(favoriteAddresses) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }
    
    private func loadFavoriteAddresses() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([FavoriteAddress].self, from: data) {
            favoriteAddresses = decoded
        }
    }
}

