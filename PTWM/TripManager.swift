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
import UserNotifications

struct AchievementBadge: Equatable, Codable, Identifiable {
    var id: String { title }
    let title: String
    let systemImage: String
    let achieved: Bool
}

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
    
    @AppStorage("defaultTripCategory") private var defaultTripCategory: String = "Business"
    @AppStorage("autoTripDetectionEnabled") private var autoTripDetectionEnabled: Bool = false
    @AppStorage("autoTripSpeedThresholdMPH") private var autoTripSpeedThresholdMPH: Double = 20.0
    @AppStorage("autoTripEndDelaySecs") private var autoTripEndDelaySecs: Double = 180.0
    @AppStorage("enableSpeedTracking") private var enableSpeedTracking: Bool = false  // NEW: speed tracking disabled by default
    @AppStorage("lifetimeMiles") private var lifetimeMiles: Double = 0.0
    @AppStorage("lifetimeDriveHours") private var _lifetimeDriveHours: Double = 0.0
    var lifetimeDriveHours: Double { _lifetimeDriveHours }
    
    @AppStorage("dailyStreak") private var dailyStreak: Int = 0
    @AppStorage("longestStreak") private var longestStreak: Int = 0
    @AppStorage("lastTripDate") private var lastTripDate: String = ""
    
    var cityMPG: Double { 
        let val = UserDefaults.standard.double(forKey: "cityMPG")
        return val > 0 ? val : 25.0
    }
    var highwayMPG: Double { 
        let val = UserDefaults.standard.double(forKey: "highwayMPG")
        return val > 0 ? val : 32.0
    }
    
    @Published var trips: [Trip] = []
    @Published var currentDistance: Double = 0.0
    @Published var backgroundImage: UIImage? = nil
    @Published var userLocation: CLLocationCoordinate2D? = nil
    @Published var favoriteAddresses: [FavoriteAddress] = []
    @Published var tripJustAutoStarted: Bool = false
    @Published var unlockedAchievement: AchievementBadge? = nil
    
    private var locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private let tripsKey = "savedTrips"
    private let backgroundKey = "savedBackground"
    private let currentTripKey = "ongoingTripState"
    private let favoritesKey = "favoriteAddressesKey"
    
    private var currentTripStartLocation: CLLocationCoordinate2D?
    private var currentTripStartTime: Date? = nil
    private var currentRoute: [CLLocationCoordinate2D] = []
    
    private var tripWasAutoStarted: Bool = false
    
    private var speedCheckTimer: Timer?
    private var belowThresholdStartDate: Date?
    private var lastSpeed: CLLocationSpeed?
    
    private var isTripStarted: Bool {
        return currentTripStartLocation != nil
    }
    
    func fuelUsed(for distance: Double, mpg: Double) -> Double {
        guard mpg > 0 else { return 0 }
        return distance / mpg
    }

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
    
    /// Saves the current trip-in-progress state (if any) to persistent storage.
    private func autosaveOngoingTripState() {
        guard let start = currentTripStartLocation, let startTime = currentTripStartTime else { return }
        let tripState = OngoingTripState(startLocation: start, startTime: startTime, route: currentRoute, distance: currentDistance)
        if let data = try? JSONEncoder().encode(tripState) {
            UserDefaults.standard.set(data, forKey: currentTripKey)
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
        
        self.endTrip(withNotes: "", pay: "", start: start, end: endpoint, route: recoveredRoute, isRecovered: true, averageSpeed: nil)
        UserDefaults.standard.removeObject(forKey: currentTripKey)
    }

    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTrip(isAutoStarted: Bool = false) {
        currentDistance = 0.0
        lastLocation = nil
        currentTripStartLocation = userLocation
        currentTripStartTime = Date()
        currentRoute = []
        tripWasAutoStarted = isAutoStarted
        tripJustAutoStarted = isAutoStarted
        belowThresholdStartDate = nil
        speedCheckTimer?.invalidate()
        speedCheckTimer = nil
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
    ///   - averageSpeed: Optional average speed to store with the trip.
    func endTrip(withNotes notes: String, pay: String, start: CLLocationCoordinate2D? = nil, end: CLLocationCoordinate2D? = nil, route: [CLLocationCoordinate2D]? = nil, audioNotes: [URL] = [], photoURLs: [URL] = [], reason: String = "", isRecovered: Bool = false, averageSpeed: Double? = nil) {
        var actualReason = reason
        if actualReason.isEmpty {
            actualReason = defaultTripCategory
        }

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
            reason: actualReason,
            isRecovered: isRecovered,
            averageSpeed: averageSpeed
        )
        // Update lifetime miles
        lifetimeMiles += newTrip.distance
        
        // Update lifetime drive hours
        _lifetimeDriveHours += newTrip.endTime.timeIntervalSince(newTrip.startTime) / 3600
        
        // --- Start of added streak logic ---
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        if lastTripDate != today {
            if !lastTripDate.isEmpty,
               let lastDate = formatter.date(from: lastTripDate),
               let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                if Calendar.current.isDate(lastDate, inSameDayAs: yesterday) {
                    // Last trip was yesterday, increment streak
                    dailyStreak += 1
                } else {
                    // Missed a day or more, reset streak
                    dailyStreak = 1
                }
            } else {
                // No previous trip date, start streak at 1
                dailyStreak = 1
            }
            lastTripDate = today
            if dailyStreak > longestStreak {
                longestStreak = dailyStreak
            }
        }
        // --- End of added streak logic ---
        
        // Check mileage achievements (same thresholds as AchievementsView)
        let mileageThresholds: [(Double, String, String)] = [
            (1, "figure.walk", "1 Mile"),
            (5, "car.fill", "5 Miles"),
            (25, "rosette", "25 Miles"),
            (100, "flag.checkered", "100 Miles"),
            (250, "star.fill", "250 Miles"),
            (500, "paperplane.fill", "500 Miles"),
            (1000, "car.2.fill", "1,000 Miles"),
            (2500, "speedometer", "2,500 Miles"),
            (5000, "trophy.fill", "5,000 Miles"),
            (10000, "crown.fill", "10,000 Miles")
        ]
        let previousMiles = lifetimeMiles - newTrip.distance
        for (threshold, symbol, title) in mileageThresholds {
            if previousMiles < threshold && lifetimeMiles >= threshold {
                unlockedAchievement = AchievementBadge(title: title, systemImage: symbol, achieved: true)
                break
            }
        }
        
        // Check time-based achievements (same as AchievementsView, in hours)
        let timeThresholds: [(Double, String, String)] = [
            (5.0/60.0, "clock.fill", "5 Minutes"),
            (30.0/60.0, "clock.fill", "30 Minutes"),
            (1, "clock.fill", "1 Hour"),
            (2, "clock.fill", "2 Hours"),
            (4, "clock.fill", "4 Hours"),
            (12, "clock.fill", "12 Hours"),
            (24, "clock.fill", "24 Hours"),
            (30, "clock.fill", "30 Hours"),
            (48, "clock.fill", "48 Hours"),
            (100, "clock.fill", "100 Hours")
        ]
        let previousHours = lifetimeDriveHours - (newTrip.endTime.timeIntervalSince(newTrip.startTime) / 3600)
        for (threshold, symbol, title) in timeThresholds {
            if previousHours < threshold && lifetimeDriveHours >= threshold {
                unlockedAchievement = AchievementBadge(title: title, systemImage: symbol, achieved: true)
                break
            }
        }
        
        trips.insert(newTrip, at: 0)
        saveTrips()
        currentTripStartLocation = nil
        currentTripStartTime = nil
        currentRoute = []
        tripWasAutoStarted = false
        belowThresholdStartDate = nil
        speedCheckTimer?.invalidate()
        speedCheckTimer = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Track distance if trip started
        if let last = lastLocation {
            let distanceDelta = newLocation.distance(from: last) / 1609.34
            currentDistance += distanceDelta
        }
        lastLocation = newLocation
        userLocation = newLocation.coordinate

        // Append to route if trip started
        if currentTripStartLocation != nil {
            currentRoute.append(newLocation.coordinate)
            print("[RouteDebug] Logged coordinate: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude). Total route points: \(currentRoute.count)")
            // Autosave trip state on every location update to ensure crash-proof trip logging
            autosaveOngoingTripState()
        }
        
        // Automatic trip detection logic
        let speed = newLocation.speed >= 0 ? newLocation.speed : 0 // Negative speed means invalid
        lastSpeed = speed
        let speedThreshold: CLLocationSpeed = autoTripSpeedThresholdMPH * 0.44704 // convert mph to m/s
        
        if autoTripDetectionEnabled && enableSpeedTracking {
            if !isTripStarted {
                if speed >= speedThreshold {
                    startTrip(isAutoStarted: true)
                    sendAutoStartNotificationIfNeeded()
                    print("[AutoTripDetection] Trip automatically started due to speed >= 20 mph.")
                }
            } else if tripWasAutoStarted {
                if speed < speedThreshold {
                    if belowThresholdStartDate == nil {
                        belowThresholdStartDate = Date()
                        startSpeedCheckTimer()
                    }
                } else {
                    belowThresholdStartDate = nil
                    stopSpeedCheckTimer()
                }
            }
        }
    }
    
    private func startSpeedCheckTimer() {
        speedCheckTimer?.invalidate()
        speedCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkSpeedTimerFired()
        }
    }
    
    private func stopSpeedCheckTimer() {
        speedCheckTimer?.invalidate()
        speedCheckTimer = nil
    }
    
    private func checkSpeedTimerFired() {
        guard let belowStart = belowThresholdStartDate else {
            stopSpeedCheckTimer()
            return
        }
        let elapsed = Date().timeIntervalSince(belowStart)
        if elapsed >= autoTripEndDelaySecs {
            print("[AutoTripDetection] Speed below threshold for 3+ minutes, ending trip.")
            // End trip automatically, with empty notes/pay, no reason to override
            endTrip(withNotes: "", pay: "")
            belowThresholdStartDate = nil
            stopSpeedCheckTimer()
        }
    }
    
    private func sendAutoStartNotificationIfNeeded() {
        // If app is in background, send a local notification to inform user of automatic trip start
        let state = UIApplication.shared.applicationState
        if state != .active {
            let content = UNMutableNotificationContent()
            content.title = "Trip Started Automatically"
            content.body = "Your trip has been automatically started based on your speed."
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: "autoTripStartNotification", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[AutoTripDetection] Failed to deliver notification: \(error.localizedDescription)")
                }
            }
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

