import Foundation
import CoreLocation

struct CodableCoordinate: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    
    // MARK: - Computed Properties
    
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var isValid: Bool {
        CLLocationCoordinate2DIsValid(clCoordinate)
    }
    
    // MARK: - Initializers
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    init?(from location: CLLocation?) {
        guard let location = location else { return nil }
        self.init(from: location.coordinate)
    }
    
    // MARK: - Methods
    
    func distance(to other: CodableCoordinate) -> CLLocationDistance {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
    
    func toLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

// MARK: - CustomStringConvertible

extension CodableCoordinate: CustomStringConvertible {
    var description: String {
        "(\(latitude), \(longitude))"
    }
}

// MARK: - Convenience Extensions

extension CLLocationCoordinate2D {
    var codable: CodableCoordinate {
        CodableCoordinate(from: self)
    }
}

extension CLLocation {
    var codableCoordinate: CodableCoordinate {
        CodableCoordinate(from: coordinate)
    }
}
