import SwiftUI
import MapKit
import CoreLocation

struct AddressSearchView: View {
    @StateObject private var searchCompleter = AddressSearchCompleter()
    @StateObject private var locationViewModel = LocationViewModel()
    @State private var searchText = ""
    @State private var selectedLocation: LocationDetail?
    @State private var showLocationDetail = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(
                    text: $searchText,
                    isFocused: $isSearchFocused,
                    onSearchTextChanged: { query in
                        searchCompleter.updateQuery(query)
                    }
                )
                .padding(.vertical, 8)
                
                Divider()
                
                ZStack {
                    if searchText.isEmpty {
                        EmptyStateView()
                    } else if searchCompleter.isSearching {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if let errorMessage = searchCompleter.errorMessage {
                        ErrorView(message: errorMessage) {
                            searchCompleter.updateQuery(searchText)
                        }
                    } else if searchCompleter.hasNoResults {
                        NoResultsView(searchQuery: searchText)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchCompleter.suggestions, id: \.self) { completion in
                                    AddressRowWithDistance(
                                        completion: completion,
                                        userLocation: searchCompleter.userLocation
                                    ) {
                                        Task {
                                            await selectLocation(completion)
                                        }
                                    }
                                    
                                    if completion != searchCompleter.suggestions.last {
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !searchText.isEmpty {
                        Button("Cancel") {
                            searchText = ""
                            isSearchFocused = false
                            searchCompleter.updateQuery("")
                        }
                        .font(.body)
                    }
                }
            }
            .sheet(isPresented: $showLocationDetail) {
                if let location = selectedLocation {
                    LocationDetailView(locationDetail: location, userLocation: searchCompleter.userLocation)
                }
            }
        }
    }
    
    private func selectLocation(_ completion: MKLocalSearchCompletion) async {
        do {
            let mapItem = try await searchCompleter.search(for: completion)
            let locationDetail = await locationViewModel.getLocationDetail(
                for: mapItem,
                from: searchCompleter.userLocation
            )
            
            await MainActor.run {
                selectedLocation = locationDetail
                showLocationDetail = true
                isSearchFocused = false
            }
        } catch {
            print("Error selecting location: \(error)")
        }
    }
}

// MARK: - Location View Model
@MainActor
class LocationViewModel: ObservableObject {
    func getLocationDetail(for mapItem: MKMapItem, from userLocation: CLLocation?) async -> LocationDetail {
        guard let itemLocation = mapItem.placemark.location else {
            return LocationDetail(
                mapItem: mapItem,
                distance: nil,
                travelTime: nil,
                address: formatAddress(mapItem.placemark)
            )
        }
        
        let distance = userLocation?.distance(from: itemLocation)
        let travelTime = await calculateTravelTime(from: userLocation, to: mapItem)
        
        return LocationDetail(
            mapItem: mapItem,
            distance: distance,
            travelTime: travelTime,
            address: formatAddress(mapItem.placemark)
        )
    }
    
    private func calculateTravelTime(from userLocation: CLLocation?, to destination: MKMapItem) async -> TimeInterval? {
        guard let userLocation = userLocation else { return nil }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = destination
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            return response.routes.first?.expectedTravelTime
        } catch {
            return nil
        }
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            if let number = placemark.subThoroughfare {
                components.append("\(number) \(street)")
            } else {
                components.append(street)
            }
        }
        
        if let city = placemark.locality {
            components.append(city)
        }
        
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        
        if let zip = placemark.postalCode {
            components.append(zip)
        }
        
        return components.joined(separator: ", ")
    }
}

// MARK: - Location Detail Model
struct LocationDetail: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    let distance: CLLocationDistance?
    let travelTime: TimeInterval?
    let address: String
    
    var formattedDistance: String {
        guard let distance = distance else { return "Distance unavailable" }
        let miles = distance / 1609.34
        if miles < 0.1 {
            return String(format: "%.0f ft", distance * 3.28084)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
    
    var formattedTravelTime: String {
        guard let travelTime = travelTime else { return "Time unavailable" }
        let minutes = Int(travelTime / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours) hr \(remainingMinutes) min" : "\(hours) hr"
        }
    }
}

// MARK: - Location Detail View
struct LocationDetailView: View {
    let locationDetail: LocationDetail
    let userLocation: CLLocation?
    @Environment(\.dismiss) var dismiss
    @State private var region: MKCoordinateRegion
    
    init(locationDetail: LocationDetail, userLocation: CLLocation?) {
        self.locationDetail = locationDetail
        self.userLocation = userLocation
        
        let center = locationDetail.mapItem.placemark.coordinate
        _region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Map View
                    Map(coordinateRegion: .constant(region), annotationItems: [locationDetail]) { location in
                        MapMarker(coordinate: location.mapItem.placemark.coordinate, tint: .red)
                    }
                    .frame(height: 250)
                    .allowsHitTesting(false)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text(locationDetail.mapItem.name ?? "Location")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if !locationDetail.address.isEmpty {
                                Text(locationDetail.address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 20)
                        
                        Divider()
                        
                        // Distance and Time Info
                        if locationDetail.distance != nil || locationDetail.travelTime != nil {
                            VStack(spacing: 16) {
                                HStack(spacing: 20) {
                                    if locationDetail.distance != nil {
                                        InfoCard(
                                            icon: "location.fill",
                                            title: "Distance",
                                            value: locationDetail.formattedDistance,
                                            color: .blue
                                        )
                                    }
                                    
                                    if locationDetail.travelTime != nil {
                                        InfoCard(
                                            icon: "car.fill",
                                            title: "Drive Time",
                                            value: locationDetail.formattedTravelTime,
                                            color: .green
                                        )
                                    }
                                }
                            }
                            
                            Divider()
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                openInMaps()
                            }) {
                                HStack {
                                    Image(systemName: "map.fill")
                                    Text("Open in Apple Maps")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.body.weight(.medium))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            if let phone = locationDetail.mapItem.phoneNumber {
                                Button(action: {
                                    if let url = URL(string: "tel://\(phone)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "phone.fill")
                                        Text(phone)
                                        Spacer()
                                    }
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.blue)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            
                            if let url = locationDetail.mapItem.url {
                                Button(action: {
                                    UIApplication.shared.open(url)
                                }) {
                                    HStack {
                                        Image(systemName: "safari.fill")
                                        Text("Visit Website")
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.blue)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Location Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func openInMaps() {
        locationDetail.mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Address Row With Distance
struct AddressRowWithDistance: View {
    let completion: MKLocalSearchCompletion
    let userLocation: CLLocation?
    let onTap: () -> Void
    @State private var distance: String?
    @State private var isCalculating = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .foregroundColor(.blue)
                    .font(.title3)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(completion.title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if !completion.subtitle.isEmpty {
                        Text(completion.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let distance = distance {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(distance)
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await calculateDistance()
        }
    }
    
    private var iconName: String {
        if completion.title.lowercased().contains("restaurant") ||
           completion.title.lowercased().contains("cafe") {
            return "fork.knife"
        } else if completion.subtitle.isEmpty {
            return "mappin.circle.fill"
        } else {
            return "mappin.and.ellipse"
        }
    }
    
    private func calculateDistance() async {
        guard let userLocation = userLocation else { return }
        
        do {
            let searchRequest = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: searchRequest)
            let response = try await search.start()
            
            if let itemLocation = response.mapItems.first?.placemark.location {
                let distanceInMeters = userLocation.distance(from: itemLocation)
                let miles = distanceInMeters / 1609.34
                
                await MainActor.run {
                    if miles < 0.1 {
                        self.distance = String(format: "%.0f ft away", distanceInMeters * 3.28084)
                    } else {
                        self.distance = String(format: "%.1f mi away", miles)
                    }
                }
            }
        } catch {
            // Silently fail - distance won't be shown
        }
    }
}

// MARK: - Supporting Views
struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSearchTextChanged: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)
                
                TextField("Enter address or place", text: $text)
                    .focused(isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onChange(of: text) { _, newValue in
                        onSearchTextChanged(newValue)
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        onSearchTextChanged("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Search for an Address")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Enter a street address, city, or place name to find locations")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct NoResultsView: View {
    let searchQuery: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Results Found")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("No locations match \"\(searchQuery)\"")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Try adjusting your search or check the spelling")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 50))
            
            Text("Something Went Wrong")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: onRetry) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    AddressSearchView()
}
