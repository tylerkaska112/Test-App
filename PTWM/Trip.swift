//
//  Trip.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import Foundation
import CoreLocation

struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    var distance: Double
    var notes: String
    var pay: String
    var audioNotes: [URL]
    var photoURLs: [URL]
    var startCoordinate: CodableCoordinate?
    var endCoordinate: CodableCoordinate?
    var routeCoordinates: [CodableCoordinate]
    var startTime: Date
    var endTime: Date
    var reason: String
    var isRecovered: Bool
    var averageSpeed: Double?
    
    // MARK: - Computed Properties
    
    /// Duration of the trip in seconds
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    /// Formatted duration string (e.g., "1h 23m")
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Distance in miles (converted from meters)
    var distanceInMiles: Double {
        distance * 0.000621371
    }
    
    /// Distance in kilometers (converted from meters)
    var distanceInKilometers: Double {
        distance / 1000.0
    }
    
    /// Formatted distance string in miles
    var formattedDistance: String {
        String(format: "%.2f mi", distanceInMiles)
    }
    
    /// Average speed in miles per hour
    var averageSpeedMPH: Double? {
        guard let speed = averageSpeed else { return nil }
        return speed * 2.23694 // Convert m/s to mph
    }
    
    /// Formatted average speed string
    var formattedAverageSpeed: String? {
        guard let mph = averageSpeedMPH else { return nil }
        return String(format: "%.1f mph", mph)
    }
    
    /// Whether this trip has any media attached
    var hasMedia: Bool {
        !audioNotes.isEmpty || !photoURLs.isEmpty
    }
    
    /// Total number of media items
    var mediaCount: Int {
        audioNotes.count + photoURLs.count
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        distance: Double,
        notes: String = "",
        pay: String = "",
        audioNotes: [URL] = [],
        photoURLs: [URL] = [],
        startCoordinate: CodableCoordinate? = nil,
        endCoordinate: CodableCoordinate? = nil,
        routeCoordinates: [CodableCoordinate] = [],
        startTime: Date,
        endTime: Date,
        reason: String = "",
        isRecovered: Bool = false,
        averageSpeed: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.distance = distance
        self.notes = notes
        self.pay = pay
        self.audioNotes = audioNotes
        self.photoURLs = photoURLs
        self.startCoordinate = startCoordinate
        self.endCoordinate = endCoordinate
        self.routeCoordinates = routeCoordinates
        self.startTime = startTime
        self.endTime = endTime
        self.reason = reason
        self.isRecovered = isRecovered
        self.averageSpeed = averageSpeed
    }
}

// MARK: - Trip Extensions

extension Trip {
    /// Creates a sample trip for previews and testing
    static var sample: Trip {
        Trip(
            distance: 25000, // 25 km
            notes: "Regular commute to office",
            pay: "$45.00",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            reason: "Business",
            averageSpeed: 15.0
        )
    }
    
    /// Validates that the trip data is consistent
    func isValid() -> Bool {
        guard endTime > startTime else { return false }
        guard distance >= 0 else { return false }
        return true
    }
    
    /// Returns a copy of the trip with updated notes
    func withNotes(_ newNotes: String) -> Trip {
        var copy = self
        copy.notes = newNotes
        return copy
    }
    
    /// Returns a copy of the trip with an added photo
    func addingPhoto(_ photoURL: URL) -> Trip {
        var copy = self
        copy.photoURLs.append(photoURL)
        return copy
    }
    
    /// Returns a copy of the trip with an added audio note
    func addingAudioNote(_ audioURL: URL) -> Trip {
        var copy = self
        copy.audioNotes.append(audioURL)
        return copy
    }
}

// MARK: - Sorting and Filtering

extension Trip {
    static func sortedByDate(_ trips: [Trip], ascending: Bool = false) -> [Trip] {
        trips.sorted { ascending ? $0.date < $1.date : $0.date > $1.date }
    }
    
    static func filterByDateRange(_ trips: [Trip], from startDate: Date, to endDate: Date) -> [Trip] {
        trips.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    static func totalDistance(for trips: [Trip]) -> Double {
        trips.reduce(0) { $0 + $1.distance }
    }
    
    static func totalDuration(for trips: [Trip]) -> TimeInterval {
        trips.reduce(0) { $0 + $1.duration }
    }
}
