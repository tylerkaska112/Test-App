import Foundation
import SwiftUI
import CoreLocation
import MapKit

struct MapPoint: Identifiable, Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let color: Color
    let timestamp: Date
    let title: String?
    let subtitle: String?
    
    init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        color: Color = .red,
        timestamp: Date = Date(),
        title: String? = nil,
        subtitle: String? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.color = color
        self.timestamp = timestamp
        self.title = title
        self.subtitle = subtitle
    }
    
    static func == (lhs: MapPoint, rhs: MapPoint) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate == rhs.coordinate &&
        lhs.timestamp == rhs.timestamp
    }
}

extension MapPoint {
    var location: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    func distance(from point: MapPoint) -> CLLocationDistance {
        location.distance(from: point.location)
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

// MARK: - Codable Support
extension MapPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, colorHex, timestamp, title, subtitle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        let hex = try container.decode(String.self, forKey: .colorHex)
        color = Color(hex: hex) ?? .red
        
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(color.toHex(), forKey: .colorHex)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
    }
}

// MARK: - Color Hex Conversion
extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#FF0000" }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
