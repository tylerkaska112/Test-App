import Foundation
import MapKit
import GeoToolbox

@MainActor
class ModernAddressSearchCompleter: NSObject, ObservableObject {
    @Published var suggestions: [PlaceDescriptor] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    
    private var searchTask: Task<Void, Never>?
    
    func updateQuery(_ query: String) async {
        searchTask?.cancel()
        errorMessage = nil
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            suggestions = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            if Task.isCancelled { return }
            
            await performSearch(query: trimmedQuery)
        }
    }
    
    private func performSearch(query: String) async {
        do {
            guard let request = MKGeocodingRequest(addressString: query) else {
                await MainActor.run {
                    self.suggestions = []
                    self.isSearching = false
                    self.errorMessage = "Invalid search query"
                }
                return
            }
            
            let mapItems = try await request.mapItems
            
            let placeDescriptors = mapItems.compactMap { mapItem in
                PlaceDescriptor(item: mapItem)
            }
            
            await MainActor.run {
                self.suggestions = placeDescriptors
                self.isSearching = false
                self.errorMessage = nil
            }
            
        } catch {
            await MainActor.run {
                self.suggestions = []
                self.isSearching = false
                self.errorMessage = "Search failed. Please try again."
            }
        }
    }
}