import AppIntents
import SwiftUI

struct StartTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Trip"
    static var description = IntentDescription("Start tracking a new trip")
    
    @Parameter(title: "Destination")
    var destination: String?
    
    @Parameter(title: "Trip Category")
    var category: TripCategoryEntity
    
    func perform() async throws -> some IntentResult {
        // Start trip logic here
        return .result(dialog: "Trip started to \(destination ?? "unknown destination")")
    }
}

struct EndTripIntent: AppIntent {
    static var title: LocalizedStringResource = "End Trip"
    static var description = IntentDescription("End the current trip")
    
    func perform() async throws -> some IntentResult {
        // End trip logic here
        return .result(dialog: "Trip ended and saved")
    }
}

struct TripCategoryEntity: AppEntity {
    var id: String
    var name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Trip Category")
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static var defaultQuery = TripCategoryQuery()
}

struct TripCategoryQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TripCategoryEntity] {
        return TripCategory.allCases.compactMap { category in
            TripCategoryEntity(id: category.rawValue, name: category.rawValue)
        }
    }
    
    func suggestedEntities() async throws -> [TripCategoryEntity] {
        return TripCategory.allCases.map { category in
            TripCategoryEntity(id: category.rawValue, name: category.rawValue)
        }
    }
}