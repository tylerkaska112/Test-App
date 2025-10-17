import Foundation
import MapKit
import Combine
import CoreLocation

class AddressSearchCompleter: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    
    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    private let searchSubject = PassthroughSubject<String, Never>()
    private let locationManager = CLLocationManager()
    
    var debounceInterval: Int = 300
    var minimumQueryLength: Int = 2
    var userLocation: CLLocation?
    
    override init() {
        super.init()
        setupLocationManager()
        setupCompleter()
        setupDebouncing()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func setupCompleter() {
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
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
        errorMessage = nil
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuery.isEmpty {
            suggestions = []
            isSearching = false
            completer.queryFragment = ""
            return
        }
        
        guard trimmedQuery.count >= minimumQueryLength else {
            suggestions = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchSubject.send(trimmedQuery)
    }
    
    private func performSearch(query: String) {
        // Set search region based on user location
        if let location = userLocation {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 50000,
                longitudinalMeters: 50000
            )
            completer.region = region
        }
        
        completer.queryFragment = query
    }
    
    // MARK: - Public Methods
    
    func clearSuggestions() {
        suggestions = []
        isSearching = false
        errorMessage = nil
        completer.queryFragment = ""
        searchSubject.send("")
    }
    
    func setSearchRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }
    
    func setSearchRegion(center: CLLocationCoordinate2D, radiusInMeters: Double = 50000) {
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusInMeters,
            longitudinalMeters: radiusInMeters
        )
        completer.region = region
    }
    
    func setResultTypes(_ types: MKLocalSearchCompleter.ResultType) {
        completer.resultTypes = types
    }
    
    func search(for completion: MKLocalSearchCompletion) async throws -> MKMapItem {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        let response = try await search.start()
        
        guard let mapItem = response.mapItems.first else {
            throw SearchError.noResults
        }
        
        return mapItem
    }
    
    func cancelSearch() {
        completer.cancel()
        isSearching = false
    }
    
    // Sort suggestions by distance from user location
    private func sortSuggestionsByDistance(_ completions: [MKLocalSearchCompletion]) async -> [MKLocalSearchCompletion] {
        guard let userLocation = userLocation else {
            return completions
        }
        
        var completionsWithDistance: [(completion: MKLocalSearchCompletion, distance: CLLocationDistance?)] = []
        
        for completion in completions {
            do {
                let mapItem = try await search(for: completion)
                if let itemLocation = mapItem.placemark.location {
                    let distance = userLocation.distance(from: itemLocation)
                    completionsWithDistance.append((completion, distance))
                } else {
                    completionsWithDistance.append((completion, nil))
                }
            } catch {
                completionsWithDistance.append((completion, nil))
            }
        }
        
        // Sort: items with distance first (ascending), then items without distance
        return completionsWithDistance.sorted { item1, item2 in
            switch (item1.distance, item2.distance) {
            case (.some(let d1), .some(let d2)):
                return d1 < d2
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return false
            }
        }.map { $0.completion }
    }
}

// MARK: - CLLocationManagerDelegate
extension AddressSearchCompleter: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        
        // Stop updating location after getting initial location to save battery
        if userLocation != nil {
            locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - Convenience Methods
extension AddressSearchCompleter {
    func fullAddress(for completion: MKLocalSearchCompletion) -> String {
        if completion.subtitle.isEmpty {
            return completion.title
        } else {
            return "\(completion.title), \(completion.subtitle)"
        }
    }
    
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
    
    var hasNoResults: Bool {
        return suggestions.isEmpty && !isSearching && errorMessage == nil
    }
    
    var hasSuggestions: Bool {
        return !suggestions.isEmpty
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension AddressSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task {
            let sortedResults = await sortSuggestionsByDistance(completer.results)
            
            await MainActor.run {
                self.suggestions = sortedResults
                self.isSearching = false
                self.errorMessage = nil
            }
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.suggestions = []
            self.isSearching = false
            
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
