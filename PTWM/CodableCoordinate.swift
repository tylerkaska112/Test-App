//
//  CodableCoordinate.swift
//  Photo Tracker
//
//  Created by tyler kaska on 6/26/25.
//

import Foundation
import CoreLocation

struct CodableCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}
