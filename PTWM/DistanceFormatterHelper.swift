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
    
    static func string(for distance: Double, useKilometers: Bool) -> String {
        let unit: DistanceUnit = useKilometers ? .kilometers : .miles
        return string(for: distance, unit: unit)
    }
    
    static func string(for distance: Double, unit: DistanceUnit) -> String {
        let value = convertedValue(distance, to: unit)
        let formatString = precisionFormat(for: value)
        return String(format: formatString, value, unit.symbol)
    }
    
    // MARK: - Private Helpers
    
    private static func convertedValue(_ miles: Double, to unit: DistanceUnit) -> Double {
        switch unit {
        case .miles:
            return miles
        case .kilometers:
            return miles * 1.60934
        }
    }
    
    private static func precisionFormat(for value: Double) -> String {
        switch value {
        case ..<10:
            return "%.2f %@"
        case ..<100:
            return "%.1f %@"
        default:
            return "%.0f %@"
        }
    }
}

// MARK: - Convenience Extensions

extension DistanceFormatterHelper {
    static func localizedString(for distance: Double) -> String {
        let usesMetric = Locale.current.measurementSystem == .metric
        return string(for: distance, useKilometers: usesMetric)
    }
}

// MARK: - Double Extension

extension Double {
    func formattedDistance(useKilometers: Bool = false) -> String {
        DistanceFormatterHelper.string(for: self, useKilometers: useKilometers)
    }
    
    var formattedDistance: String {
        DistanceFormatterHelper.localizedString(for: self)
    }
}
