//
//  TripManager.swift
//  waylon
//
//  Enhanced with improved features and user experience
//

import Foundation
import CoreLocation
import SwiftUI
import UIKit
import UserNotifications

struct FavoriteAddress: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var address: String
    var coordinate: CodableCoordinate?
    var category: String // NEW: Home, Work, Client, etc.
    var notes: String // NEW: Additional context
    
    init(id: UUID = UUID(), name: String, address: String, coordinate: CodableCoordinate? = nil, category: String = "Other", notes: String = "") {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.category = category
        self.notes = notes
    }
}

class TripManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - App Storage Properties
    @AppStorage("defaultTripCategory") private var defaultTripCategory: String = "Business"
    @AppStorage("autoTripDetectionEnabled") private var autoTripDetectionEnabled: Bool = false
    @AppStorage("autoTripSpeedThresholdMPH") private var autoTripSpeedThresholdMPH: Double = 20.0
    @AppStorage("autoTripEndDelaySecs") private var autoTripEndDelaySecs: Double = 180.0
    @AppStorage("enableSpeedTracking") private var enableSpeedTracking: Bool = false
    @AppStorage("lifetimeMiles") private var lifetimeMiles: Double = 0.0
    @AppStorage("lifetimeDriveHours") private var _lifetimeDriveHours: Double = 0.0
    @AppStorage("dailyStreak") private var dailyStreak: Int = 0
    @AppStorage("longestStreak") private var longestStreak: Int = 0
    @AppStorage("lastTripDate") private var lastTripDate: String = ""
    @AppStorage("smartPauseEnabled") private var smartPauseEnabled: Bool = true // NEW
    @AppStorage("batteryOptimizationEnabled") private var batteryOptimizationEnabled: Bool = true // NEW
    @AppStorage("roundTripDetection") private var roundTripDetection: Bool = true // NEW
    
    var lifetimeDriveHours: Double { _lifetimeDriveHours }
    
    var cityMPG: Double {
        let val = UserDefaults.standard.double(forKey: "cityMPG")
        return val > 0 ? val : 25.0
    }
    var highwayMPG: Double {
        let val = UserDefaults.standard.double(forKey: "highwayMPG")
        return val > 0 ? val : 32.0
    }
    
    // MARK: - Published Properties
    @Published var trips: [Trip] = []
    @Published var currentDistance: Double = 0.0
    @Published var backgroundImage: UIImage? = nil
    @Published var userLocation: CLLocationCoordinate2D? = nil
    @Published var favoriteAddresses: [FavoriteAddress] = []
    @Published var tripJustAutoStarted: Bool = false
    @Published var unlockedAchievement: AchievementBadge? = nil
    @Published var currentSpeed: Double = 0.0 // NEW: Real-time speed in MPH
    @Published var currentTripDuration: TimeInterval = 0 // NEW: Real-time duration
    @Published var estimatedArrivalTime: Date? = nil // NEW: ETA to destination
    @Published var isPaused: Bool = false // NEW: Trip pause state
    @Published var batteryLevel: Float = 1.0 // NEW: Current battery level
    
    // MARK: - Private Properties
    private var locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private let tripsKey = "savedTrips"
    private let backgroundKey = "savedBackground"
    private let currentTripKey = "ongoingTripState"
    private let favoritesKey = "favoriteAddressesKey"
    
    private var currentTripStartLocation: CLLocationCoordinate2D?
    private var currentTripStartTime: Date? = nil
    private var currentRoute: [CLLocationCoordinate2D] = []
    private var pausedRoute: [CLLocationCoordinate2D] = [] // NEW: Route before pause
    private var pauseStartTime: Date? = nil // NEW
    private var totalPausedDuration: TimeInterval = 0 // NEW
    
    private var tripWasAutoStarted: Bool = false
    private var speedCheckTimer: Timer?
    private var durationTimer: Timer? // NEW
    private var belowThresholdStartDate: Date?
    private var lastSpeed: CLLocationSpeed?
    
    // NEW: Smart pause detection
    private var stationaryStartTime: Date?
    private let smartPauseThreshold: TimeInterval = 120 // 2 minutes stationary = auto-pause
    
    // NEW: Round trip detection
    private var possibleRoundTrip: Bool = false
    
    private var isTripStarted: Bool {
        return currentTripStartLocation != nil
    }
    
    // MARK: - Fuel Calculations
    func fuelUsed(for distance: Double, mpg: Double) -> Double {
        guard mpg > 0 else { return 0 }
        return distance / mpg
    }
    
    func estimatedFuelCost(for distance: Double, pricePerGallon: Double) -> Double {
        let avgMPG = (cityMPG + highwayMPG) / 2
        let gallons = fuelUsed(for: distance, mpg: avgMPG)
        return gallons * pricePerGallon
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .automotiveNavigation // NEW: Better for driving
        locationManager.startUpdatingLocation()
        
        loadTrips()
        loadBackground()
        loadFavoriteAddresses()
        setupNotifications()
        monitorBatteryLevel()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackgrounding), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackgrounding), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        restoreOngoingTripIfNeeded()
    }
    
    // MARK: - Battery Monitoring (NEW)
    private func monitorBatteryLevel() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        
        NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.batteryLevel = UIDevice.current.batteryLevel
            self?.adjustLocationAccuracyForBattery()
        }
    }
    
    private func adjustLocationAccuracyForBattery() {
        guard batteryOptimizationEnabled else { return }
        
        if batteryLevel < 0.20 {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 50
        } else if batteryLevel < 0.50 {
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 10
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = kCLDistanceFilterNone
        }
    }
    
    // MARK: - Notifications Setup (NEW)
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
    // MARK: - Trip Pause/Resume (NEW)
    func pauseTrip() {
        guard !isPaused, currentTripStartLocation != nil else { return }
        isPaused = true
        pauseStartTime = Date()
        pausedRoute = currentRoute
        durationTimer?.invalidate()
        
        // Reduce location accuracy during pause to save battery
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100
        
        sendNotification(title: "Trip Paused", body: "Your trip tracking is paused. Resume when ready.")
    }
    
    func resumeTrip() {
        guard isPaused else { return }
        isPaused = false
        
        if let pauseStart = pauseStartTime {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        
        // Restore location accuracy
        adjustLocationAccuracyForBattery()
        startDurationTimer()
        
        sendNotification(title: "Trip Resumed", body: "Tracking your trip again.")
    }
    
    // MARK: - Smart Pause Detection (NEW)
    private func checkForSmartPause(speed: CLLocationSpeed) {
        guard smartPauseEnabled, !isPaused, currentTripStartLocation != nil else { return }
        
        if speed < 0.5 { // Essentially stationary (< 1 mph)
            if stationaryStartTime == nil {
                stationaryStartTime = Date()
            } else if let startTime = stationaryStartTime,
                      Date().timeIntervalSince(startTime) >= smartPauseThreshold {
                pauseTrip()
                stationaryStartTime = nil
            }
        } else {
            stationaryStartTime = nil
        }
    }
    
    // MARK: - Round Trip Detection (NEW)
    private func checkForRoundTrip(currentLocation: CLLocationCoordinate2D) {
        guard roundTripDetection, let startLocation = currentTripStartLocation else { return }
        
        let startCLLocation = CLLocation(latitude: startLocation.latitude, longitude: startLocation.longitude)
        let currentCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let distance = currentCLLocation.distance(from: startCLLocation)
        
        // If within 100 meters of start location
        if distance < 100 && currentDistance > 0.5 { // More than 0.5 miles traveled
            possibleRoundTrip = true
            sendNotification(title: "Round Trip Detected", body: "You're back near your starting point. End trip?")
        }
    }
    
    // MARK: - Duration Timer (NEW)
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.currentTripStartTime, !self.isPaused else { return }
            self.currentTripDuration = Date().timeIntervalSince(startTime) - self.totalPausedDuration
        }
    }
    
    // MARK: - Background Handling
    @objc private func handleAppBackgrounding() {
        if currentTripStartLocation != nil, let start = currentTripStartLocation, let startTime = currentTripStartTime {
            let tripState = OngoingTripState(
                startLocation: start,
                startTime: startTime,
                route: currentRoute,
                distance: currentDistance,
                isPaused: isPaused,
                totalPausedDuration: totalPausedDuration
            )
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
        let isPaused: Bool
        let totalPausedDuration: TimeInterval
        
        init(startLocation: CLLocationCoordinate2D, startTime: Date, route: [CLLocationCoordinate2D], distance: Double, isPaused: Bool, totalPausedDuration: TimeInterval) {
            self.startLocation = CodableCoordinate(from: startLocation)
            self.startTime = startTime
            self.route = route.map { CodableCoordinate(from: $0) }
            self.distance = distance
            self.isPaused = isPaused
            self.totalPausedDuration = totalPausedDuration
        }
    }
    
    private func autosaveOngoingTripState() {
        guard let start = currentTripStartLocation, let startTime = currentTripStartTime else { return }
        let tripState = OngoingTripState(
            startLocation: start,
            startTime: startTime,
            route: currentRoute,
            distance: currentDistance,
            isPaused: isPaused,
            totalPausedDuration: totalPausedDuration
        )
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
        self.isPaused = state.isPaused
        self.totalPausedDuration = state.totalPausedDuration
        
        var recoveredRoute = state.route.map { $0.clCoordinate }
        let endpoint: CLLocationCoordinate2D? = userLocation ?? recoveredRoute.last
        
        if recoveredRoute.isEmpty {
            if let endpoint = endpoint, endpoint != start {
                recoveredRoute = [start, endpoint]
            } else {
                recoveredRoute = [start, start]
            }
        } else if recoveredRoute.count == 1 {
            if let endpoint = endpoint, endpoint != recoveredRoute[0] {
                recoveredRoute.append(endpoint)
            } else {
                recoveredRoute.append(recoveredRoute[0])
            }
        } else {
            if let endpoint = endpoint, recoveredRoute.last != endpoint {
                recoveredRoute.append(endpoint)
            }
        }
        
        var totalDistanceMiles = 0.0
        for i in 1..<recoveredRoute.count {
            let prev = recoveredRoute[i-1]
            let curr = recoveredRoute[i]
            let prevLoc = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
            let currLoc = CLLocation(latitude: curr.latitude, longitude: curr.longitude)
            totalDistanceMiles += currLoc.distance(from: prevLoc) / 1609.34
        }
        self.currentDistance = totalDistanceMiles
        
        sendNotification(title: "Trip Recovered", body: "Your previous trip was recovered and saved.")
        self.endTrip(withNotes: "", pay: "", start: start, end: endpoint, route: recoveredRoute, isRecovered: true, averageSpeed: nil)
        UserDefaults.standard.removeObject(forKey: currentTripKey)
    }
    
    // MARK: - Notification Helper (NEW)
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Location Permission
    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Trip Management
    func startTrip(isAutoStarted: Bool = false) {
        currentDistance = 0.0
        lastLocation = nil
        currentTripStartLocation = userLocation
        currentTripStartTime = Date()
        currentRoute = []
        currentTripDuration = 0
        totalPausedDuration = 0
        isPaused = false
        pauseStartTime = nil
        possibleRoundTrip = false
        tripWasAutoStarted = isAutoStarted
        tripJustAutoStarted = isAutoStarted
        belowThresholdStartDate = nil
        stationaryStartTime = nil
        
        speedCheckTimer?.invalidate()
        speedCheckTimer = nil
        durationTimer?.invalidate()
        startDurationTimer()
        
        UserDefaults.standard.removeObject(forKey: currentTripKey)
        
        if isAutoStarted {
            sendNotification(title: "Trip Auto-Started", body: "Your trip has been automatically detected and started.")
        }
    }
    
    func endTrip(withNotes notes: String, pay: String, start: CLLocationCoordinate2D? = nil, end: CLLocationCoordinate2D? = nil, route: [CLLocationCoordinate2D]? = nil, audioNotes: [URL] = [], photoURLs: [URL] = [], reason: String = "", isRecovered: Bool = false, averageSpeed: Double? = nil) {
        
        durationTimer?.invalidate()
        durationTimer = nil
        
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
            paddedRoute.append(paddedRoute[0])
        }
        
        let tripStartTime = currentTripStartTime ?? Date()
        let tripEndTime = Date()
        let actualStart = start ?? currentTripStartLocation
        let actualEnd = end ?? userLocation
        
        let newTrip = Trip(
            id: UUID(),
            date: tripStartTime,
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
        
        lifetimeMiles += newTrip.distance
        _lifetimeDriveHours += (newTrip.endTime.timeIntervalSince(newTrip.startTime) - totalPausedDuration) / 3600
        
        updateStreaks()
        checkAchievements(newTrip: newTrip)
        
        trips.insert(newTrip, at: 0)
        saveTrips()
        
        currentTripStartLocation = nil
        currentTripStartTime = nil
        currentRoute = []
        currentTripDuration = 0
        totalPausedDuration = 0
        isPaused = false
        pauseStartTime = nil
        tripWasAutoStarted = false
        possibleRoundTrip = false
        belowThresholdStartDate = nil
        stationaryStartTime = nil
        
        speedCheckTimer?.invalidate()
        speedCheckTimer = nil
        
        sendNotification(title: "Trip Completed", body: String(format: "%.2f miles tracked", newTrip.distance))
    }
    
    // MARK: - Streak Management (Improved)
    private func updateStreaks() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        if lastTripDate != today {
            if !lastTripDate.isEmpty,
               let lastDate = formatter.date(from: lastTripDate),
               let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                if Calendar.current.isDate(lastDate, inSameDayAs: yesterday) {
                    dailyStreak += 1
                } else {
                    dailyStreak = 1
                }
            } else {
                dailyStreak = 1
            }
            lastTripDate = today
            if dailyStreak > longestStreak {
                longestStreak = dailyStreak
                sendNotification(title: "New Record!", body: "You've reached your longest streak: \(longestStreak) days!")
            }
        }
    }
    
    // MARK: - Achievement Checking (Enhanced)
    private func checkAchievements(newTrip: Trip) {
        let mileageThresholds: [(Double, String, String)] = [
            (1, "figure.walk", "First Mile"),
            (5, "car.fill", "5 Miles"),
            (25, "rosette", "25 Miles"),
            (50, "star.circle.fill", "50 Miles"),
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
                unlockedAchievement = AchievementBadge(
                    title: title,
                    systemImage: symbol,
                    achieved: true,
                    description: "Congratulations on reaching \(threshold) lifetime miles!",
                    currentValue: lifetimeMiles,
                    targetValue: threshold,
                    unlockedDate: Date(),
                    valueFormatter: { value in String(format: "%.0f", value) }
                )
                sendNotification(title: "Achievement Unlocked! 🏆", body: "\(title) milestone reached!")
                break
            }
        }
    }
    
    // MARK: - Location Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        userLocation = newLocation.coordinate
        
        // Update current speed
        if newLocation.speed >= 0 {
            currentSpeed = newLocation.speed * 2.23694 // Convert m/s to mph
            lastSpeed = newLocation.speed
        }
        
        guard !isPaused else { return }
        
        if let last = lastLocation {
            let distanceDelta = newLocation.distance(from: last) / 1609.34
            currentDistance += distanceDelta
        }
        lastLocation = newLocation
        
        if currentTripStartLocation != nil {
            currentRoute.append(newLocation.coordinate)
            autosaveOngoingTripState()
            
            // Check for round trip
            checkForRoundTrip(currentLocation: newLocation.coordinate)
            
            // Check for smart pause
            if let speed = lastSpeed {
                checkForSmartPause(speed: speed)
            }
        }
        
        // Auto trip detection
        handleAutoTripDetection(newLocation: newLocation)
    }
    
    private func handleAutoTripDetection(newLocation: CLLocation) {
        guard autoTripDetectionEnabled, enableSpeedTracking else { return }
        
        let speed = newLocation.speed >= 0 ? newLocation.speed : 0
        let speedThreshold: CLLocationSpeed = autoTripSpeedThresholdMPH * 0.44704
        
        if !isTripStarted {
            if speed >= speedThreshold {
                startTrip(isAutoStarted: true)
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
            endTrip(withNotes: "", pay: "")
            belowThresholdStartDate = nil
            stopSpeedCheckTimer()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            print("Location authorized")
        }
    }
    
    // MARK: - Trip CRUD Operations
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
    
    func deleteTrip(trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        saveTrips()
    }
    
    // MARK: - Persistence
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
    
    // MARK: - Favorite Addresses
    func addFavoriteAddress(_ favorite: FavoriteAddress) {
        favoriteAddresses.append(favorite)
        saveFavoriteAddresses()
    }
    
    func updateFavoriteAddress(_ updated: FavoriteAddress) {
        if let index = favoriteAddresses.firstIndex(where: { $0.id == updated.id }) {
            favoriteAddresses[index] = updated
            saveFavoriteAddresses()
        }
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
    
    // MARK: - Utility Methods
    func hasLocationPermission() -> Bool {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }
    
    func refreshIfNeeded() {
        if trips.isEmpty { loadTrips() }
        if favoriteAddresses.isEmpty { loadFavoriteAddresses() }
        if backgroundImage == nil { loadBackground() }
    }
    
    func saveCurrentState() {
        saveTrips()
        saveFavoriteAddresses()
        saveBackground()
        autosaveOngoingTripState()
    }
    
    // NEW: Export trip data
    func exportTrips() -> String {
        var csv = "Date,Distance (mi),Duration (hrs),Notes,Pay,Reason\n"
        for trip in trips {
            let duration = trip.endTime.timeIntervalSince(trip.startTime) / 3600
            csv += "\(trip.date),\(trip.distance),\(duration),\(trip.notes),\(trip.pay),\(trip.reason)\n"
        }
        return csv
    }
}
