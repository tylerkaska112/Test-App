//  DistanceFormatterHelper.swift
//  waylonApp
//  Created by Assistant on 7/1/25.

import Foundation

struct DistanceFormatterHelper {
    
    enum DistanceUnit {
        case miles
        case kilometers
        
        var symbol: String {
            switch self {
            case .miles: return NSLocalizedString("mi", comment: "Miles abbreviation")
            case .kilometers: return NSLocalizedString("km", comment: "Kilometers abbreviation")
            }
        }
    }
    
    /// Returns a formatted distance string based on the value and unit.
    /// - Parameters:
    ///   - distance: The distance value in miles
    ///   - useKilometers: If true, converts and formats as kilometers. If false, formats as miles.
    /// - Returns: A localized string representing the distance, e.g., "3.7 mi" or "6.0 km"
    static func string(for distance: Double, useKilometers: Bool) -> String {
        let unit: DistanceUnit = useKilometers ? .kilometers : .miles
        return string(for: distance, unit: unit)
    }
    
    /// Returns a formatted distance string based on the value and unit.
    /// - Parameters:
    ///   - distance: The distance value in miles
    ///   - unit: The desired unit for display
    /// - Returns: A localized string representing the distance
    static func string(for distance: Double, unit: DistanceUnit) -> String {
        let value = convertedValue(distance, to: unit)
        let formatString = precisionFormat(for: value)
        return String(format: formatString, value, unit.symbol)
    }
    
    // MARK: - Private Helpers
    
    /// Converts a distance in miles to the specified unit
    private static func convertedValue(_ miles: Double, to unit: DistanceUnit) -> Double {
        switch unit {
        case .miles:
            return miles
        case .kilometers:
            return miles * 1.60934
        }
    }
    
    /// Returns the appropriate format string based on the distance value
    private static func precisionFormat(for value: Double) -> String {
        switch value {
        case ..<10:
            return "%.2f %@"  // e.g., 3.75 mi
        case ..<100:
            return "%.1f %@"  // e.g., 45.3 mi
        default:
            return "%.0f %@"  // e.g., 234 mi
        }
    }
}

// MARK: - Convenience Extensions

extension DistanceFormatterHelper {
    /// Formats distance using system locale preferences
    static func localizedString(for distance: Double) -> String {
        let usesMetric = Locale.current.measurementSystem == .metric
        return string(for: distance, useKilometers: usesMetric)
    }
}

// MARK: - Double Extension

extension Double {
    /// Convenience method to format distance
    func formattedDistance(useKilometers: Bool = false) -> String {
        DistanceFormatterHelper.string(for: self, useKilometers: useKilometers)
    }
    
    /// Formats distance using system locale preferences
    var formattedDistance: String {
        DistanceFormatterHelper.localizedString(for: self)
    }
}
