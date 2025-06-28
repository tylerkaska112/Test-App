//
//  Trip.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import Foundation
import CoreLocation

struct Trip: Identifiable, Codable {
    let id: UUID
    let date: Date
    var distance: Double
    var notes: String
    var pay: String
    var startCoordinate: CodableCoordinate?
    var endCoordinate: CodableCoordinate?
    var routeCoordinates: [CodableCoordinate]
    var startTime: Date
    var endTime: Date
}
