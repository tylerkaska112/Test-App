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
    var isRecovered: Bool = false // Indicates if this trip was recovered after app termination
    var averageSpeed: Double? // meters per second

    init(
        id: UUID,
        date: Date,
        distance: Double,
        notes: String,
        pay: String,
        audioNotes: [URL],
        photoURLs: [URL] = [],
        startCoordinate: CodableCoordinate?,
        endCoordinate: CodableCoordinate?,
        routeCoordinates: [CodableCoordinate],
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

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case distance
        case notes
        case pay
        case audioNotes
        case photoURLs
        case startCoordinate
        case endCoordinate
        case routeCoordinates
        case startTime
        case endTime
        case reason
        case isRecovered
        case averageSpeed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        distance = try container.decode(Double.self, forKey: .distance)
        notes = try container.decode(String.self, forKey: .notes)
        pay = try container.decode(String.self, forKey: .pay)
        audioNotes = try container.decode([URL].self, forKey: .audioNotes)
        photoURLs = try container.decode([URL].self, forKey: .photoURLs)
        startCoordinate = try container.decodeIfPresent(CodableCoordinate.self, forKey: .startCoordinate)
        endCoordinate = try container.decodeIfPresent(CodableCoordinate.self, forKey: .endCoordinate)
        routeCoordinates = try container.decode([CodableCoordinate].self, forKey: .routeCoordinates)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        reason = try container.decode(String.self, forKey: .reason)
        isRecovered = try container.decodeIfPresent(Bool.self, forKey: .isRecovered) ?? false
        averageSpeed = try container.decodeIfPresent(Double.self, forKey: .averageSpeed)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(distance, forKey: .distance)
        try container.encode(notes, forKey: .notes)
        try container.encode(pay, forKey: .pay)
        try container.encode(audioNotes, forKey: .audioNotes)
        try container.encode(photoURLs, forKey: .photoURLs)
        try container.encodeIfPresent(startCoordinate, forKey: .startCoordinate)
        try container.encodeIfPresent(endCoordinate, forKey: .endCoordinate)
        try container.encode(routeCoordinates, forKey: .routeCoordinates)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(reason, forKey: .reason)
        try container.encode(isRecovered, forKey: .isRecovered)
        try container.encodeIfPresent(averageSpeed, forKey: .averageSpeed)
    }
}
