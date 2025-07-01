//
//  MapPoint.swift
//  Photo Tracker
//
//  Created by tyler kaska on 6/26/25.
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit


struct MapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let color: Color
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
