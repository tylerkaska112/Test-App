import Foundation
import MapKit

@MainActor
class AsyncAddressSearchCompleter: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    
    private let completer = MKLocalSearchCompleter()
    private var searchTask: Task<Void, Never>?
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
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
        completer.queryFragment = query
    }
}

extension AsyncAddressSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
            self.isSearching = false
            self.errorMessage = nil
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.isSearching = false
            
            switch error {
            case let mkError as MKError:
                switch mkError.code {
                case .placemarkNotFound:
                    self.errorMessage = "No results found for your search."
                case .serverFailure:
                    self.errorMessage = "Search service is temporarily unavailable."
                case .loadingThrottled:
                    self.errorMessage = "Too many search requests. Please try again in a moment."
                default:
                    self.errorMessage = "Search failed. Please try again."
                }
            default:
                self.errorMessage = "An unexpected error occurred."
            }
        }
    }
}
