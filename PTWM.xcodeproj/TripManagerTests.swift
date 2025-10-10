import Testing
import Foundation
@testable import PTWM

@Suite("Trip Management Tests") 
struct TripManagerTests {
    
    @Test("Distance calculation accuracy")
    func testDistanceCalculation() async throws {
        let manager = TripManager()
        
        // Test locations (Apple Park to Golden Gate Bridge)
        let start = CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
        let end = CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783)
        
        let distance = manager.calculateDistance(from: start, to: end)
        
        // Should be approximately 37 miles
        #expect(distance > 35 && distance < 40, "Distance should be approximately 37 miles")
    }
    
    @Test("Premium manager state handling")
    func testPremiumManagerState() async throws {
        let premiumManager = PremiumManager.shared
        
        // Test initial state
        #expect(premiumManager.purchaseInProgress == false, "Purchase should not be in progress initially")
        
        // Test error clearing
        await premiumManager.refreshStatus()
        #expect(premiumManager.purchaseError == nil, "Error should be cleared after refresh")
    }
    
    @Test("Address search completer functionality") 
    func testAddressSearchCompleter() async throws {
        let completer = AsyncAddressSearchCompleter()
        
        // Test empty query
        await completer.updateQuery("")
        #expect(completer.suggestions.isEmpty, "Empty query should return no suggestions")
        #expect(completer.isSearching == false, "Should not be searching for empty query")
        
        // Test non-empty query
        await completer.updateQuery("Apple Park")
        // Allow time for debouncing
        try await Task.sleep(for: .milliseconds(500))
        
        #expect(completer.isSearching == false, "Should have completed search")
    }
}