import Foundation
import MapKit
import Combine

class AddressSearchCompleter: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    
    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    private let searchSubject = PassthroughSubject<String, Never>()
    
    override init() {
        super.init()
        setupCompleter()
        setupDebouncing()
    }
    
    private func setupCompleter() {
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    private func setupDebouncing() {
        searchSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    func updateQuery(_ query: String) {
        // Clear previous error when starting new search
        errorMessage = nil
        
        // Handle empty query
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            suggestions = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchSubject.send(query)
    }
    
    private func performSearch(query: String) {
        completer.queryFragment = query
    }
    
    // MARK: - Public Methods
    
    /// Clear all suggestions and reset state
    func clearSuggestions() {
        suggestions = []
        isSearching = false
        errorMessage = nil
        completer.queryFragment = ""
    }
    
    /// Configure search region for more relevant results
    func setSearchRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }
    
    /// Filter results by type
    func setResultTypes(_ types: MKLocalSearchCompleter.ResultType) {
        completer.resultTypes = types
    }
}

// MARK: - Convenience Methods
extension AddressSearchCompleter {
    /// Get the full address string for a completion
    func fullAddress(for completion: MKLocalSearchCompletion) -> String {
        if completion.subtitle.isEmpty {
            return completion.title
        } else {
            return "\(completion.title), \(completion.subtitle)"
        }
    }
    
    /// Check if suggestions list is empty but not because of error
    var hasNoResults: Bool {
        return suggestions.isEmpty && !isSearching && errorMessage == nil
    }
}

extension AddressSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
            self.isSearching = false
            self.errorMessage = nil
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.suggestions = []
            self.isSearching = false
            
            // Provide user-friendly error messages
            switch error {
            case let mkError as MKError:
                switch mkError.code {
                case .unknown:
                    self.errorMessage = "An unknown error occurred. Please try again."
                case .serverFailure:
                    self.errorMessage = "Search service is temporarily unavailable."
                case .loadingThrottled:
                    self.errorMessage = "Too many search requests. Please try again in a moment."
                case .placemarkNotFound:
                    self.errorMessage = "No results found for your search."
                default:
                    self.errorMessage = "Search failed. Please try again."
                }
            default:
                self.errorMessage = "An unexpected error occurred."
            }
        }
    }
}

