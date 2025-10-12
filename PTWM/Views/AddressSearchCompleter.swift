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
    
    // Configurable properties
    var debounceInterval: Int = 300 // milliseconds
    var minimumQueryLength: Int = 2
    
    override init() {
        super.init()
        setupCompleter()
        setupDebouncing()
    }
    
    private func setupCompleter() {
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        // Set a reasonable point of interest filter for better results
        if #available(iOS 13.0, *) {
            completer.pointOfInterestFilter = MKPointOfInterestFilter.includingAll
        }
    }
    
    private func setupDebouncing() {
        searchSubject
            .debounce(for: .milliseconds(debounceInterval), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    func updateQuery(_ query: String) {
        // Clear previous error when starting new search
        errorMessage = nil
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty query
        if trimmedQuery.isEmpty {
            suggestions = []
            isSearching = false
            completer.queryFragment = ""
            return
        }
        
        // Only search if query meets minimum length requirement
        guard trimmedQuery.count >= minimumQueryLength else {
            suggestions = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchSubject.send(trimmedQuery)
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
        searchSubject.send("") // Clear any pending searches
    }
    
    /// Configure search region for more relevant results
    func setSearchRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }
    
    /// Configure search region from user's location
    func setSearchRegion(center: CLLocationCoordinate2D, radiusInMeters: Double = 50000) {
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusInMeters,
            longitudinalMeters: radiusInMeters
        )
        completer.region = region
    }
    
    /// Filter results by type
    func setResultTypes(_ types: MKLocalSearchCompleter.ResultType) {
        completer.resultTypes = types
    }
    
    /// Perform a full search for a completion to get detailed information
    func search(for completion: MKLocalSearchCompletion) async throws -> MKMapItem {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        let response = try await search.start()
        
        guard let mapItem = response.mapItems.first else {
            throw SearchError.noResults
        }
        
        return mapItem
    }
    
    /// Cancel all active searches
    func cancelSearch() {
        completer.cancel()
        isSearching = false
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
    
    /// Get attributed text with highlighted matching text
    func attributedTitle(for completion: MKLocalSearchCompletion) -> NSAttributedString {
        return completion.titleHighlightRanges.isEmpty ?
            NSAttributedString(string: completion.title) :
            highlightedString(completion.title, ranges: completion.titleHighlightRanges)
    }
    
    func attributedSubtitle(for completion: MKLocalSearchCompletion) -> NSAttributedString {
        return completion.subtitleHighlightRanges.isEmpty ?
            NSAttributedString(string: completion.subtitle) :
            highlightedString(completion.subtitle, ranges: completion.subtitleHighlightRanges)
    }
    
    private func highlightedString(_ text: String, ranges: [NSValue]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
        ]
        
        for value in ranges {
            let range = value.rangeValue
            if range.location != NSNotFound && range.location + range.length <= text.count {
                attributedString.addAttributes(highlightAttributes, range: range)
            }
        }
        
        return attributedString
    }
    
    /// Check if suggestions list is empty but not because of error
    var hasNoResults: Bool {
        return suggestions.isEmpty && !isSearching && errorMessage == nil
    }
    
    /// Check if there are valid suggestions to display
    var hasSuggestions: Bool {
        return !suggestions.isEmpty
    }
}

// MARK: - MKLocalSearchCompleterDelegate
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
            if let mkError = error as? MKError {
                switch mkError.code {
                case .unknown:
                    self.errorMessage = "An unknown error occurred. Please try again."
                case .serverFailure:
                    self.errorMessage = "Search service is temporarily unavailable."
                case .loadingThrottled:
                    self.errorMessage = "Too many search requests. Please wait a moment."
                case .placemarkNotFound:
                    self.errorMessage = "No results found. Try a different search term."
                case .directionsNotFound:
                    self.errorMessage = "Unable to find this location."
                default:
                    self.errorMessage = "Search failed. Please try again."
                }
            } else if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                self.errorMessage = "No internet connection. Please check your network."
            } else {
                self.errorMessage = "An unexpected error occurred. Please try again."
            }
        }
    }
}

// MARK: - Custom Errors
enum SearchError: LocalizedError {
    case noResults
    case invalidCompletion
    
    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No results found for this location."
        case .invalidCompletion:
            return "Invalid search result selected."
        }
    }
}
