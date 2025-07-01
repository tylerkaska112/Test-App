import SwiftUI
import MapKit
import CoreLocation
import AVFoundation
import Foundation
import Charts

// Add useKilometers AppStorage here


// MARK: - Address Search Completer
final class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { self.suggestions = [] }
    }
}

// MARK: - Distance Formatter Helper
struct DistanceFormatterHelper {
    static func string(for miles: Double, useKilometers: Bool) -> String {
        if useKilometers {
            let km = miles * 1.60934
            if km < 1 {
                let meters = Int(km * 1000)
                return "\(meters) m"
            } else {
                return String(format: "%.2f km", km)
            }
        } else {
            if miles < 0.1 {
                let feet = Int(miles * 5280)
                return "\(feet) ft"
            } else {
                return String(format: "%.2f mi", miles)
            }
        }
    }
}

// MARK: - Main Express Ride View
struct ExpressRideView: View {
    @EnvironmentObject private var tripManager: TripManager
    @StateObject private var searchCompleter = AddressSearchCompleter()
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var showBanner = false
    
    @AppStorage("userHomeAddress") private var userHomeAddress: String = ""
    @AppStorage("userWorkAddress") private var userWorkAddress: String = ""
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    @AppStorage("selectedMapStyle") private var selectedMapStyle: Int = 0
    @AppStorage("navigationVoiceIdentifier") private var navigationVoiceIdentifier: String = ""

    // UI State
    @State private var isTripStarted = false
    @State private var showAddressPanel = true
    @State private var destinationAddress = ""
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var route: MKRoute?
    @State private var navigationStepIndex = 0
    @State private var navigationSteps: [MKRoute.Step] = []
    @State private var showingRouteError = false
    @State private var addressSuggestions: [MKLocalSearchCompletion] = []
    @State private var showSuggestions = false
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var shouldRecenter = false
    @State private var routeDistanceMiles: Double? = nil
    @State private var remainingMiles: Double? = nil
    
    @State private var isRerouting = false
    @State private var lastRerouteTime: Date? = nil
    
    @State private var estimatedTravelTime: TimeInterval? = nil
    
    // Track if a suggestion from the list has been selected (to avoid double searches)
    @State private var selectedSuggestion: MKLocalSearchCompletion? = nil
    
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var lastSpokenStepIndex: Int? = nil
    
    @State private var isMuted = false
    
    // New state to track if final reminder has been spoken
    @State private var hasSpokenFinalReminder: Bool = false
    
    @State private var showMileageReport = false
    
    @State private var showFavoritesSheet = false
    
    var body: some View {
        let mapType: MKMapType
        switch selectedMapStyle {
        case 1: mapType = .satellite
        case 2: mapType = .hybrid
        case 3: mapType = .mutedStandard
        default: mapType = .standard
        }
        
        return ZStack(alignment: .top) {
            if showBanner {
                WelcomeBackBanner()
                    .zIndex(10)
            }
            if isRerouting {
                Text("Rerouting...")
                    .padding(12)
                    .background(Color.yellow.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.top, 60)
                    .transition(.opacity)
            }
            mapLayer(mapType: mapType)
            if let _ = route, !navigationSteps.isEmpty, isTripStarted {
                VStack(spacing: 2) {
                    navigationInstructions
                    distanceBanner
                }
                .padding(.top, 6)
            }
            if route != nil && isTripStarted { recenterButton }
            VStack { Spacer(); bottomPanel }
            
            if !(route != nil && isTripStarted) {
                HStack {
                    VStack(spacing: 14) {
                        Button(action: { showFavoritesSheet = true }) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                                .padding(8)
                        }
                        .accessibilityLabel("Show Favorite Addresses")
                    }
                    .padding(.top, 32)
                    .padding(.leading, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .background(BackgroundWrapper(content: { EmptyView() }))
        .alert("Route Error", isPresented: $showingRouteError) { Button("OK", role: .cancel) {} }
        .onChange(of: tripManager.userLocation) { _ in
            checkStepProximity()
            updateRemainingMiles()
            checkOffRouteAndReroute()
        }
        .onReceive(searchCompleter.$suggestions) { addressSuggestions = $0 }
        .onChange(of: navigationStepIndex) { newIndex in
            hasSpokenFinalReminder = false
            speakCurrentStep(reminder: false)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                showBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showBanner = false
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showMileageReport = true
                } label: {
                    Label("Mileage Report", systemImage: "chart.bar.doc.horizontal")
                }
            }
        }
        .sheet(isPresented: $showMileageReport) {
            MileageReportView().environmentObject(tripManager)
        }
        .sheet(isPresented: $showFavoritesSheet) {
            NavigationView {
                List(tripManager.favoriteAddresses) { fav in
                    Button(action: {
                        destinationAddress = fav.address
                        selectedSuggestion = nil
                        geocodeAndShowRoute()
                        showFavoritesSheet = false
                    }) {
                        VStack(alignment: .leading) {
                            Text(fav.name).bold()
                            Text(fav.address).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .navigationTitle("Favorite Addresses")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showFavoritesSheet = false }
                    }
                }
            }
        }
    }

    // MARK: - Map Layer
    private func mapLayer(mapType: MKMapType) -> some View {
        Group {
            if let userLocation = tripManager.userLocation {
                RouteMapView(userLocation: userLocation, route: route, isNavigating: isTripStarted, shouldRecenter: $shouldRecenter, mapType: mapType)
                    .ignoresSafeArea()
            } else {
                Text("Map unavailable")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.15))
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Distance Banner
    private var distanceBanner: some View {
        HStack {
            Text("Distance: \(DistanceFormatterHelper.string(for: tripManager.currentDistance, useKilometers: useKilometers))")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Text("    ")
                .font(.headline)
                .foregroundColor(.white)
            
            if let eta = estimatedTravelTime {
                Text("ETA: \(formatETA(eta))")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Recenter Button
    private var recenterButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 16) {
                    Button {
                        isMuted.toggle()
                    } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.9)).frame(width: 44, height: 44).shadow(radius: 2)
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                                .foregroundColor(isMuted ? .red : .blue)
                                .font(.system(size: 22, weight: .semibold))
                        }
                    }
                    .padding(.trailing, 16)
                    .accessibilityIdentifier("MuteUnmuteButton")

                    Button {
                        shouldRecenter = true
                    } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.9)).frame(width: 44, height: 44).shadow(radius: 2)
                            Image(systemName: "location.north.line.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 22, weight: .semibold))
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 180)
            }
        }.transition(.opacity)
    }

    // MARK: - Navigation Instructions
    private var navigationInstructions: some View {
        let step = navigationSteps[navigationStepIndex]
        // Calculate distance to the next step's start
        let userLoc = tripManager.userLocation
        let stepCoord: CLLocationCoordinate2D = {
            if step.polyline.pointCount > 0 {
                return step.polyline.coordinate
            } else {
                return destinationCoordinate ?? userLoc ?? CLLocationCoordinate2D()
            }
        }()
        let distanceText: String = {
            guard let userLoc else { return "" }
            let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            let stepCL = CLLocation(latitude: stepCoord.latitude, longitude: stepCoord.longitude)
            let distance = userCL.distance(from: stepCL)
            if distance <= 300 * 0.3048 {
                // Show in feet
                let feet = distance * 3.28084
                return "In \(Int(feet)) ft"
            } else {
                let miles = distance / 1609.34
                return "In \(DistanceFormatterHelper.string(for: miles, useKilometers: useKilometers))"
            }
        }()

        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(distanceText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.blue)
                    .accessibilityIdentifier("NextTurnDistance")
                Text(step.instructions)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("NextTurnInstruction")
            }
            Spacer()
            VStack(spacing: 10) {
                Button(action: { if navigationStepIndex > 0 { 
                    navigationStepIndex -= 1
                    hasSpokenFinalReminder = false
                } }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(navigationStepIndex == 0 ? .gray : .blue)
                }
                .disabled(navigationStepIndex == 0)
                Button(action: { if navigationStepIndex < navigationSteps.count - 1 { 
                    navigationStepIndex += 1
                    hasSpokenFinalReminder = false
                } }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(navigationStepIndex == navigationSteps.count - 1 ? .gray : .blue)
                }
                .disabled(navigationStepIndex == navigationSteps.count - 1)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .transition(.opacity)
        .animation(.easeInOut, value: navigationStepIndex)
    }

    // MARK: - Bottom Panel
    @ViewBuilder
    private var bottomPanel: some View {
        if route != nil && isTripStarted {
            navigationBottomPanel
        } else {
            tripStartBottomPanel
        }
    }

    private var navigationBottomPanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Navigating to:").font(.caption).foregroundColor(.secondary)
                    Text(destinationAddress.isEmpty ? coordinateString : destinationAddress )
                        .font(.headline).lineLimit(1).truncationMode(.tail)
                    if let miles = remainingMiles {
                        Text("Distance to destination: \(DistanceFormatterHelper.string(for: miles, useKilometers: useKilometers))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("End Navigation") { clearNavigation() }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            Button("End Trip") { endTrip() }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var tripStartBottomPanel: some View {
        VStack(spacing: 8) {
            distanceBanner
            addressPanelToggle
            if showAddressPanel { addressEntryPanel }
            Button(isTripStarted ? "End Trip" : "Start Trip") {
                if isTripStarted {
                    endTrip()
                } else {
                    isTripStarted = true
                    tripManager.startTrip()
                    showAddressPanel = false
                    showSuggestions = false
                    addressSuggestions = []
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isTripStarted ? Color.red : Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .animation(.easeInOut, value: showAddressPanel)
    }

    private var addressPanelToggle: some View {
        HStack {
            Spacer()
            Button(action: { showAddressPanel.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: showAddressPanel ? "chevron.up" : "chevron.down")
                    Text(showAddressPanel ? "Hide" : "Show Address Entry")
                }
                .font(.caption)
                .foregroundColor(.primary)
            }
        }.padding(.horizontal, 8)
    }

    private var addressEntryPanel: some View {
        VStack(spacing: 0) {
            // Removed Home/Work buttons here as per instructions
            
            ZStack {
                TextField("Enter destination address", text: $destinationAddress, onEditingChanged: { isEditing in
                    showSuggestions = isEditing && !destinationAddress.isEmpty
                    if isEditing {
                        selectedSuggestion = nil
                    }
                })
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .accessibilityIdentifier("DestinationAddressTextField")
                .onChange(of: destinationAddress) { newValue in
                    selectedSuggestion = nil
                    debounceWorkItem?.cancel()
                    if newValue.isEmpty {
                        showSuggestions = false
                        addressSuggestions = []
                    } else {
                        showSuggestions = true
                        let work = DispatchWorkItem { searchCompleter.updateQuery(newValue) }
                        debounceWorkItem = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
                    }
                }
            }
            .padding(.horizontal, 8)

            if showSuggestions && !addressSuggestions.isEmpty {
                suggestionsList
            }
        }
    }

    private var suggestionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(addressSuggestions, id: \.self) { suggestion in
                    Button(action: {
                        selectedSuggestion = suggestion
                        showSuggestions = false
                        addressSuggestions = []
                        destinationAddress = suggestion.title + (suggestion.subtitle.isEmpty ? "" : ", \(suggestion.subtitle)")
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        searchCompletionAndShowRoute(completion: suggestion)
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .bold()
                                .font(.caption)
                                .foregroundColor(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
        }
        .frame(maxHeight: 90)
        .padding(.horizontal, 8)
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Helpers
    private var coordinateString: String {
        guard let coord = destinationCoordinate else { return "" }
        return String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
    }

    private func geocodeAndShowRoute() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(destinationAddress) { placemarks, error in
            guard error == nil, let placemark = placemarks?.first,
                  let destinationLoc = placemark.location,
                  let userCoordinate = tripManager.userLocation else {
                showingRouteError = true
                return
            }
            destinationCoordinate = destinationLoc.coordinate
            createRoute(from: userCoordinate, to: destinationLoc.coordinate)
        }
    }

    private func searchCompletionAndShowRoute(completion: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard error == nil,
                  let mapItem = response?.mapItems.first,
                  let userCoordinate = tripManager.userLocation else {
                showingRouteError = true
                return
            }
            destinationCoordinate = mapItem.placemark.coordinate
            destinationAddress = completion.title + (completion.subtitle.isEmpty ? "" : ", \(completion.subtitle)")
            createRoute(from: userCoordinate, to: mapItem.placemark.coordinate)
        }
    }

    private func createRoute(from sourceCoord: CLLocationCoordinate2D, to destCoord: CLLocationCoordinate2D) {
        let sourcePlacemark = MKPlacemark(coordinate: sourceCoord)
        let destPlacemark = MKPlacemark(coordinate: destCoord)
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destPlacemark)
        request.transportType = .automobile
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard error == nil, let route = response?.routes.first else {
                showingRouteError = true
                return
            }
            self.route = route
            self.estimatedTravelTime = route.expectedTravelTime
            self.routeDistanceMiles = route.distance / 1609.34
            self.navigationSteps = route.steps.filter { !$0.instructions.isEmpty }
            self.navigationStepIndex = 0
            updateRemainingMiles()
            // Removed speakCurrentStep call here per instructions
            // speakCurrentStep(reminder: false)
        }
    }

    private func checkStepProximity() {
        guard navigationStepIndex < navigationSteps.count, let userLoc = tripManager.userLocation else { return }
        let step = navigationSteps[navigationStepIndex]
        let stepLocation: CLLocationCoordinate2D
        if step.polyline.pointCount > 0 {
            stepLocation = step.polyline.coordinate
        } else {
            stepLocation = destinationCoordinate ?? userLoc
        }
        let user = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let stepCL = CLLocation(latitude: stepLocation.latitude, longitude: stepLocation.longitude)
        let distance = user.distance(from: stepCL)
        if distance < 30 {
            if hasSpokenFinalReminder == false {
                speakCurrentStep(reminder: true)
                hasSpokenFinalReminder = true
            }
            if navigationStepIndex < navigationSteps.count - 1 {
                navigationStepIndex += 1
                hasSpokenFinalReminder = false
                // Removed speech call here; onChange will handle it
            }
        }
    }

    private func updateRemainingMiles() {
        guard let route = route, navigationStepIndex < navigationSteps.count, let userLoc = tripManager.userLocation else {
            remainingMiles = nil
            return
        }
        var remainingDistance = 0.0
        // Sum remaining steps' distances
        for step in navigationSteps[navigationStepIndex...] {
            remainingDistance += step.distance
        }
        // Add distance from user to next step's start
        let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let nextStep = navigationSteps[navigationStepIndex]
        let stepCoord = nextStep.polyline.pointCount > 0 ? nextStep.polyline.coordinate : (destinationCoordinate ?? userLoc)
        let stepLocation = CLLocation(latitude: stepCoord.latitude, longitude: stepCoord.longitude)
        let distanceToStep = userLocation.distance(from: stepLocation)
        // Remove the first step's distance, then add actual user->step distance
        remainingDistance -= nextStep.distance
        remainingDistance += distanceToStep
        remainingMiles = remainingDistance / 1609.34
    }

    private func clearNavigation() {
        route = nil
        destinationCoordinate = nil
        navigationSteps = []
        navigationStepIndex = 0
        routeDistanceMiles = nil
        remainingMiles = nil
        destinationAddress = ""
        selectedSuggestion = nil
        estimatedTravelTime = nil
        lastSpokenStepIndex = nil
        hasSpokenFinalReminder = false
        speechSynthesizer.stopSpeaking(at: .immediate)
        showSuggestions = false
        addressSuggestions = []
    }

    private func endTrip() {
        isTripStarted = false
        tripManager.endTrip(
            withNotes: "",
            pay: "",
            start: nil,
            end: nil,
            audioNotes: [],
            photoURLs: []
        )
        clearNavigation()
        showAddressPanel = true
    }

    private func closestDistanceToRoute(from location: CLLocation) -> CLLocationDistance? {
        guard let polyline = route?.polyline else { return nil }
        var minDistance = Double.greatestFiniteMagnitude
        let pointCount = polyline.pointCount
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        for coord in coords {
            let polyLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let dist = location.distance(from: polyLoc)
            if dist < minDistance { minDistance = dist }
        }
        return minDistance
    }

    private func checkOffRouteAndReroute() {
        guard isTripStarted, let route = route, let userLoc = tripManager.userLocation else { return }
        let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        guard let minDist = closestDistanceToRoute(from: userCL) else { return }
        if minDist > 40 {
            let now = Date()
            if isRerouting { return }
            if let last = lastRerouteTime, now.timeIntervalSince(last) < 10 { return }
            isRerouting = true
            lastRerouteTime = now
            rerouteFromCurrentLocation()
        }
    }

    private func rerouteFromCurrentLocation() {
        guard let userCoordinate = tripManager.userLocation, let destination = destinationCoordinate else {
            isRerouting = false
            return
        }
        let sourcePlacemark = MKPlacemark(coordinate: userCoordinate)
        let destPlacemark = MKPlacemark(coordinate: destination)
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destPlacemark)
        request.transportType = .automobile
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            DispatchQueue.main.async {
                if let newRoute = response?.routes.first {
                    self.route = newRoute
                    self.estimatedTravelTime = newRoute.expectedTravelTime
                    self.routeDistanceMiles = newRoute.distance / 1609.34
                    self.navigationSteps = newRoute.steps.filter { !$0.instructions.isEmpty }
                    self.navigationStepIndex = 0
                    self.updateRemainingMiles()
                    // Removed speakCurrentStep call here per instructions
                    // self.speakCurrentStep(reminder: false)
                }
                self.isRerouting = false
            }
        }
    }
    
    private func formatETA(_ seconds: TimeInterval) -> String {
        if seconds >= 3600 {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600 + 59) / 60
            return "\(hours) hr \(minutes) min"
        } else {
            let min = Int((seconds + 59) / 60)
            return "\(min) min"
        }
    }

    private func speakCurrentStep(reminder: Bool = false) {
        guard isTripStarted else { return }
        guard !isMuted else { return }
        guard navigationStepIndex < navigationSteps.count else { return }
        let step = navigationSteps[navigationStepIndex]
        let instruction = step.instructions
        guard !instruction.isEmpty else { return }
        if reminder == false && lastSpokenStepIndex == navigationStepIndex { return } // Prevent duplicate speech for normal
        
        var spokenInstruction: String
        
        if reminder == true {
            // Just speak the instruction (no distance prefix)
            spokenInstruction = instruction
        } else {
            // Add distance phrase before instruction
            if let userLoc = tripManager.userLocation {
                let stepCoord: CLLocationCoordinate2D = {
                    if step.polyline.pointCount > 0 {
                        return step.polyline.coordinate
                    } else {
                        return destinationCoordinate ?? userLoc
                    }
                }()
                let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                let stepCL = CLLocation(latitude: stepCoord.latitude, longitude: stepCoord.longitude)
                let distance = userCL.distance(from: stepCL)
                if distance <= 300 * 0.3048 {
                    let feet = Int(distance * 3.28084)
                    spokenInstruction = "In \(feet) feet, " + instruction
                } else {
                    let miles = distance / 1609.34
                    let distanceStr = DistanceFormatterHelper.string(for: miles, useKilometers: useKilometers).replacingOccurrences(of: " ", with: "")
                    spokenInstruction = "In \(distanceStr), \(instruction)"
                }
            } else {
                spokenInstruction = instruction
            }
        }
        let utterance = AVSpeechUtterance(string: spokenInstruction)
        
        // Use navigationVoiceIdentifier if non-empty and voice available
        if !navigationVoiceIdentifier.isEmpty, let customVoice = AVSpeechSynthesisVoice(identifier: navigationVoiceIdentifier) {
            utterance.voice = customVoice
        } else {
            // Try Apple Maps navigation Siri voices (full and compact), fallback to en-US, then Samantha, then any en-US voice, then preferred device language
            let preferredVoiceIdentifiers = [
                "com.apple.ttsbundle.siri_female_en-US_compact",
                "com.apple.ttsbundle.siri_female_en-US"
            ]
            var mapsVoice: AVSpeechSynthesisVoice? = nil
            for id in preferredVoiceIdentifiers {
                if let v = AVSpeechSynthesisVoice(identifier: id) {
                    mapsVoice = v
                    break
                }
            }
            // Next best: Samantha
            if mapsVoice == nil {
                mapsVoice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.super-compact.en-US.Samantha")
            }
            // Next best: any en-US voice
            if mapsVoice == nil {
                mapsVoice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "en-US" })
            }
            // Fallback: system preferred language
            if mapsVoice == nil {
                let lang = Locale.preferredLanguages.first ?? "en-US"
                mapsVoice = AVSpeechSynthesisVoice(language: lang)
            }
            utterance.voice = mapsVoice
        }
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
        if reminder == false {
            lastSpokenStepIndex = navigationStepIndex
        }
    }
    
    private func navigateToQuickAddress(_ address: String) {
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        destinationAddress = address
        selectedSuggestion = nil // clear suggestion
        geocodeAndShowRoute()
        showSuggestions = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Polyline Coordinate Extension
private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Map View
struct RouteMapView: UIViewRepresentable {
    var userLocation: CLLocationCoordinate2D
    var route: MKRoute?
    var isNavigating: Bool
    @Binding var shouldRecenter: Bool
    var mapType: MKMapType

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        mapView.userTrackingMode = isNavigating ? .followWithHeading : .follow
        mapView.mapType = mapType
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.mapType = mapType
        
        let heading = uiView.userLocation.heading?.trueHeading ?? uiView.userLocation.location?.course ?? 0
        let currentRegionCenter = uiView.region.center
        let currentCenterLocation = CLLocation(latitude: currentRegionCenter.latitude, longitude: currentRegionCenter.longitude)
        let newCenterLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let distance = currentCenterLocation.distance(from: newCenterLocation)

        if isNavigating {
            let distanceAhead: CLLocationDistance = 60
            let centerCoordinate = coordinate(from: userLocation, distanceMeters: distanceAhead, bearingDegrees: heading)
            let camera = MKMapCamera(lookingAtCenter: centerCoordinate, fromDistance: 350, pitch: 70, heading: heading)
            uiView.setCamera(camera, animated: true)
            if shouldRecenter {
                uiView.userTrackingMode = .followWithHeading
                DispatchQueue.main.async { self.shouldRecenter = false }
            }
        } else {
            if shouldRecenter || distance > 10 {
                let region = MKCoordinateRegion(center: userLocation, latitudinalMeters: 800, longitudinalMeters: 800)
                uiView.setRegion(region, animated: true)
                context.coordinator.lastUserLocation = userLocation
                context.coordinator.lastCameraDistance = nil
                context.coordinator.lastHeading = nil
                if uiView.userTrackingMode != .follow { uiView.userTrackingMode = .follow }
            }
            if shouldRecenter {
                DispatchQueue.main.async { self.shouldRecenter = false }
            }
        }

        context.coordinator.lastRoutePolyline = route?.polyline
        uiView.removeOverlays(uiView.overlays)
        if let route = route { uiView.addOverlay(route.polyline) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func coordinate(from coordinate: CLLocationCoordinate2D, distanceMeters: CLLocationDistance, bearingDegrees: CLLocationDegrees) -> CLLocationCoordinate2D {
        let earthRadius = 6378137.0
        let bearingRadians = bearingDegrees * .pi / 180
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(distanceMeters / earthRadius) + cos(lat1) * sin(distanceMeters / earthRadius) * cos(bearingRadians))
        let lon2 = lon1 + atan2(sin(bearingRadians) * sin(distanceMeters / earthRadius) * cos(lat1), cos(distanceMeters / earthRadius) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var lastUserLocation: CLLocationCoordinate2D?
        var lastRoutePolyline: MKPolyline?
        var lastCameraDistance: CLLocationDistance?
        var lastHeading: CLLocationDirection?
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

