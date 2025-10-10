//  DistanceFormatterHelper.swift
//  waylonApp
//  Created by Assistant on 7/1/25.

import Foundation

struct DistanceFormatterHelper {
    /// Returns a formatted distance string based on the value and unit.
    /// - Parameters:
    ///   - distance: The distance value (in miles if useKilometers is false, kilometers if true)
    ///   - useKilometers: If true, formats as kilometers. If false, as miles.
    /// - Returns: A localized string representing the distance, e.g., "3.7 mi" or "6.0 km"
    static func string(for distance: Double, useKilometers: Bool) -> String {
        let value: Double
        let unit: String
        if useKilometers {
            value = distance * 1.60934
            unit = "km"
        } else {
            value = distance
            unit = "mi"
        }
        if value < 10 {
            return String(format: "%.2f %@", value, unit)
        } else if value < 100 {
            return String(format: "%.1f %@", value, unit)
        } else {
            return String(format: "%.0f %@", value, unit)
        }
    }
}
