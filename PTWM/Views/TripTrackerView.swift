import SwiftUI
import MapKit
import CoreLocation
import AVFoundation
import Foundation
import Charts

// MARK: - Navigation State Model
struct NavigationState {
    var route: MKRoute?
    var destinationCoordinate: CLLocationCoordinate2D?
    var destinationAddress: String = ""
    var navigationSteps: [MKRoute.Step] = []
    var currentStepIndex: Int = 0
    var routeDistanceMiles: Double?
    var remainingMiles: Double?
    var estimatedTravelTime: TimeInterval?
    var isRerouting: Bool = false
    var lastRerouteTime: Date?
    
    var isNavigating: Bool {
        route != nil && !navigationSteps.isEmpty
    }
    
    mutating func reset() {
        route = nil
        destinationCoordinate = nil
        destinationAddress = ""
        navigationSteps = []
        currentStepIndex = 0
        routeDistanceMiles = nil
        remainingMiles = nil
        estimatedTravelTime = nil
        isRerouting = false
        lastRerouteTime = nil
    }
}

// MARK: - Map View Wrapper (defined before ExpressRideView)

struct RouteMapViewWrapper: UIViewRepresentable {
    var userLocation: CLLocationCoordinate2D
    var route: MKRoute?
    var isNavigating: Bool
    @Binding var shouldRecenter: Bool
    var mapType: MKMapType
    var showPOI: Bool
    var show3DBuildings: Bool
    var showCompass: Bool
    var showScale: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        mapView.userTrackingMode = isNavigating ? .followWithHeading : .follow
        mapView.mapType = mapType
        
        // Apply settings - FIXED: Use showsScale instead of showScale
        mapView.pointOfInterestFilter = showPOI ? .includingAll : .excludingAll
        mapView.showsCompass = showCompass
        mapView.showsScale = showScale  // FIXED: This is the correct property name
        
        // Enable 3D buildings
        if show3DBuildings {
            mapView.camera.pitch = 45
        }
        
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.mapType = mapType
        uiView.pointOfInterestFilter = showPOI ? .includingAll : .excludingAll
        uiView.showsCompass = showCompass
        uiView.showsScale = showScale  // FIXED: This is the correct property name
        
        let heading = uiView.userLocation.heading?.trueHeading ?? uiView.userLocation.location?.course ?? 0
        let currentRegionCenter = uiView.region.center
        let currentCenterLocation = CLLocation(latitude: currentRegionCenter.latitude, longitude: currentRegionCenter.longitude)
        let newCenterLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let distance = currentCenterLocation.distance(from: newCenterLocation)

        if isNavigating {
            let distanceAhead: CLLocationDistance = 100
            let centerCoordinate = coordinate(from: userLocation, distanceMeters: distanceAhead, bearingDegrees: heading)
            
            let pitch: CGFloat = show3DBuildings ? 60 : 0
            let camera = MKMapCamera(lookingAtCenter: centerCoordinate, fromDistance: 400, pitch: pitch, heading: heading)
            
            CATransaction.begin()
            CATransaction.setAnimationDuration(1.0)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
            uiView.setCamera(camera, animated: true)
            CATransaction.commit()
            
            context.coordinator.lastHeading = heading
            context.coordinator.lastUserLocation = userLocation
            
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

// MARK: - Search Results
struct EnhancedSearchResult: Identifiable {
    let id = UUID()
    let completion: MKLocalSearchCompletion
    var distance: Double?
    var travelTime: TimeInterval?
    var isCalculating: Bool = false
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
    
    // Consolidated Navigation State
    @State private var navigationState = NavigationState()
    
    // UI State
    @State private var activeSearchTasks: [UUID: Task<Void, Never>] = [:]
    @State private var enhancedSearchResults: [EnhancedSearchResult] = []
    @State private var showSpeedWarning = false
    @State private var isTripStarted = false
    @State private var showAddressPanel = true
    @State private var showingRouteError = false
    @State private var routeErrorMessage = "Unable to calculate route. Please check your destination address."
    @State private var addressSuggestions: [MKLocalSearchCompletion] = []
    @State private var showSuggestions = false
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var shouldRecenter = false
    @State private var selectedSuggestion: MKLocalSearchCompletion?
    @State private var isMuted = false
    @State private var hasSpokenFinalReminder: Bool = false
    @State private var showMileageReport = false
    @State private var showFavoritesSheet = false
    @State private var showEndTripConfirmation = false
    @State private var isCalculatingRoute = false
    @AppStorage("showPOIOnMap") private var showPOIOnMap: Bool = true
    @AppStorage("show3DBuildings") private var show3DBuildings: Bool = true
    @AppStorage("showMapCompass") private var showMapCompass: Bool = true
    @AppStorage("showMapScale") private var showMapScale: Bool = false
    @AppStorage("speedLimitWarningEnabled") private var speedLimitWarningEnabled: Bool = false
    @AppStorage("speedLimitThreshold") private var speedLimitThreshold: Double = 75.0
    @AppStorage("fontSizeMultiplier") private var fontSizeMultiplier: Double = 1.0
    @AppStorage("enableSpeedTracking") private var enableSpeedTracking: Bool = false
    
    // Speech
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var lastSpokenStepIndex: Int?
    
    var body: some View {
        let mapType = getMapType()
        
        return ZStack(alignment: .top) {
            // Welcome Banner
            if showBanner {
                Text("Welcome Back!")
                    .font(.headline)
                    .padding(12)
                    .background(Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 3)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
            
            // Rerouting Indicator
            if navigationState.isRerouting {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Rerouting...")
                }
                .padding(12)
                .background(Color.yellow.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 3)
                .padding(.top, 60)
                .transition(.opacity)
                .zIndex(9)
            }
            
            // Route Calculation Indicator
            if isCalculatingRoute {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Calculating route...")
                }
                .padding(12)
                .background(Color.blue.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 3)
                .padding(.top, 60)
                .transition(.opacity)
                .zIndex(9)
            }
            
            // Map Layer
            mapLayer(mapType: mapType)
            
            // Navigation UI
            if navigationState.isNavigating && isTripStarted {
                VStack(spacing: 2) {
                    navigationInstructions
                    distanceBanner
                }
                .padding(.top, 6)
            }
            
            // Recenter & Mute Buttons
            if navigationState.route != nil && isTripStarted {
                recenterButton
            }
            
            // Bottom Panel
            VStack {
                Spacer()
                bottomPanel
            }
            
            // Favorites Button (only when not navigating)
            if !(navigationState.route != nil && isTripStarted) {
                favoritesButton
            }
        }
        .background(BackgroundWrapper(content: { EmptyView() }))
        .alert("Route Error", isPresented: $showingRouteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(routeErrorMessage)
        }
        .confirmationDialog("End Trip", isPresented: $showEndTripConfirmation, titleVisibility: .visible) {
            Button("End Trip", role: .destructive) {
                performEndTrip()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this trip? Your trip data will be saved.")
        }
        .onChange(of: tripManager.userLocation) { _ in
            handleLocationUpdate()
        }
        .onReceive(searchCompleter.$suggestions) { suggestions in
            addressSuggestions = suggestions
            updateEnhancedSearchResults(from: suggestions)
        }
        .onChange(of: navigationState.currentStepIndex) { _ in
            handleStepChange()
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
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
                Group {
                    if tripManager.favoriteAddresses.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No Favorite Addresses")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Add favorite addresses in Settings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(tripManager.favoriteAddresses) { fav in
                            Button(action: {
                                selectFavorite(fav.address)
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fav.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(fav.address)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .navigationTitle("Favorite Addresses")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showFavoritesSheet = false }
                    }
                }
            }
        }
    }
    
    // MARK: - SPEED DISPLAY COMPONENT
    
    private var speedDisplayOverlay: some View {
        Group {
            if enableSpeedTracking && isTripStarted && tripManager.currentSpeed > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("\(Int(tripManager.currentSpeed))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Text(useKilometers ? "km/h" : "mph")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(16)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                        )
                        .shadow(radius: 8)
                        .padding(.trailing, 16)
                        .padding(.bottom, navigationState.route != nil ? 240 : 200)
                    }
                }
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Map Layer
    private func mapLayer(mapType: MKMapType) -> some View {
        Group {
            if let userLocation = tripManager.userLocation {
                RouteMapViewWrapper(
                    userLocation: userLocation,
                    route: navigationState.route,
                    isNavigating: isTripStarted,
                    shouldRecenter: $shouldRecenter,
                    mapType: mapType,
                    showPOI: showPOIOnMap,
                    show3DBuildings: show3DBuildings,
                    showCompass: showMapCompass,
                    showScale: showMapScale
                )
                .ignoresSafeArea()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Navigation Map")
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Waiting for location...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
                .ignoresSafeArea()
            }
            
            if showSpeedWarning && speedLimitWarningEnabled {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Speed Warning")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("You're exceeding \(Int(speedLimitThreshold)) mph")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Spacer()
                        Button(action: { showSpeedWarning = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.95))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    .padding(.horizontal)
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(11)
            }
        }
    }

    // MARK: - Distance Banner
    private var distanceBanner: some View {
        HStack {
            // Distance
            Text("Distance: \(DistanceFormatterHelper.string(for: tripManager.currentDistance, useKilometers: useKilometers))")
                .font(.system(size: 17 * fontSizeMultiplier, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Spacer().frame(width: 12)
            
            // Current Speed (if speed tracking enabled)
            if enableSpeedTracking && tripManager.currentSpeed > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 14 * fontSizeMultiplier))
                    Text("\(Int(tripManager.currentSpeed)) mph")
                        .font(.system(size: 17 * fontSizeMultiplier, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Spacer().frame(width: 12)
            }
            
            // ETA
            if let eta = navigationState.estimatedTravelTime {
                Text("ETA: \(formatETA(eta))")
                    .font(.system(size: 17 * fontSizeMultiplier, weight: .semibold))
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
    
    // MARK: - Favorites Button
    private var favoritesButton: some View {
        HStack {
            VStack(spacing: 14) {
                Button(action: {
                    provideFeedback(.light)
                    showFavoritesSheet = true
                }) {
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
                .accessibilityHint("Opens a list of your saved favorite destinations")
            }
            .padding(.top, 32)
            .padding(.leading, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .transition(.opacity)
        .zIndex(20)
    }
    
    // MARK: - Recenter Button
    private var recenterButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 16) {
                    // Mute Button
                    Button {
                        provideFeedback(.medium)
                        isMuted.toggle()
                        announceVoiceStatus()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 44, height: 44)
                                .shadow(radius: 2)
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundColor(isMuted ? .red : .blue)
                                .font(.system(size: 22, weight: .semibold))
                        }
                    }
                    .accessibilityLabel(isMuted ? "Unmute voice guidance" : "Mute voice guidance")
                    .accessibilityHint("Toggles voice navigation instructions")
                    .accessibilityIdentifier("MuteUnmuteButton")
                    
                    // Recenter Button
                    Button {
                        provideFeedback(.light)
                        shouldRecenter = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 44, height: 44)
                                .shadow(radius: 2)
                            Image(systemName: "location.north.line.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 22, weight: .semibold))
                        }
                    }
                    .accessibilityLabel("Recenter map")
                    .accessibilityHint("Centers the map on your current location")
                }
                .padding(.trailing, 16)
                .padding(.bottom, 180)
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Navigation Instructions
    private var navigationInstructions: some View {
        guard navigationState.currentStepIndex < navigationState.navigationSteps.count else {
            return AnyView(EmptyView())
        }
        
        let step = navigationState.navigationSteps[navigationState.currentStepIndex]
        let distanceText = calculateDistanceToStep(step)
        
        return AnyView(
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(distanceText)
                        .font(.system(size: 22 * fontSizeMultiplier, weight: .bold))
                        .foregroundStyle(Color.blue)
                        .accessibilityIdentifier("NextTurnDistance")
                    Text(step.instructions)
                        .font(.system(size: 18 * fontSizeMultiplier, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier("NextTurnInstruction")
                }
                Spacer()
                VStack(spacing: 10) {
                    Button(action: {
                        provideFeedback(.light)
                        moveToStep(navigationState.currentStepIndex - 1)
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(navigationState.currentStepIndex == 0 ? .gray : .blue)
                    }
                    .disabled(navigationState.currentStepIndex == 0)
                    
                    Button(action: {
                        provideFeedback(.light)
                        moveToStep(navigationState.currentStepIndex + 1)
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(navigationState.currentStepIndex == navigationState.navigationSteps.count - 1 ? .gray : .blue)
                    }
                    .disabled(navigationState.currentStepIndex == navigationState.navigationSteps.count - 1)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .transition(.opacity)
            .animation(.easeInOut, value: navigationState.currentStepIndex)
            .accessibilityElement(children: .contain)
        )
    }
    
    // MARK: - Bottom Panel
    @ViewBuilder
    private var bottomPanel: some View {
        if navigationState.route != nil && isTripStarted {
            navigationBottomPanel
        } else {
            tripStartBottomPanel
        }
    }
    
    private var navigationBottomPanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Navigating to:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(navigationState.destinationAddress.isEmpty ? coordinateString : navigationState.destinationAddress)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let miles = navigationState.remainingMiles {
                        Text("Distance to destination: \(DistanceFormatterHelper.string(for: miles, useKilometers: useKilometers))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("End Navigation") {
                    provideFeedback(.medium)
                    clearNavigation()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
                .accessibilityHint("Stops navigation but continues the trip")
            }
            Button("End Trip") {
                provideFeedback(.medium)
                showEndTripConfirmation = true
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
            .accessibilityHint("Ends the current trip and saves trip data")
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
                provideFeedback(.medium)
                if isTripStarted {
                    showEndTripConfirmation = true
                } else {
                    startTrip()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isTripStarted ? Color.red : Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .accessibilityLabel(isTripStarted ? "End Trip" : "Start Trip")
            .accessibilityHint(isTripStarted ? "Ends the current trip" : "Begins tracking your trip")
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
            Button(action: {
                provideFeedback(.light)
                withAnimation { showAddressPanel.toggle() }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: showAddressPanel ? "chevron.up" : "chevron.down")
                    Text(showAddressPanel ? "Hide" : "Show Address Entry")
                }
                .font(.caption)
                .foregroundColor(.primary)
            }
            .accessibilityLabel(showAddressPanel ? "Hide address entry" : "Show address entry")
        }
        .padding(.horizontal, 8)
    }
    
    private var addressEntryPanel: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
                
                TextField(
                    "Search for a place or address",
                    text: $navigationState.destinationAddress,
                    onEditingChanged: { isEditing in
                        showSuggestions = isEditing && !navigationState.destinationAddress.isEmpty
                        if isEditing {
                            selectedSuggestion = nil
                        }
                    }
                )
                .font(.system(size: 16))
                .accessibilityIdentifier("DestinationAddressTextField")
                .accessibilityLabel("Destination address")
                .accessibilityHint("Enter the address you want to navigate to")
                .onChange(of: navigationState.destinationAddress) { newValue in
                    handleAddressChange(newValue)
                }
                
                if !navigationState.destinationAddress.isEmpty {
                    Button(action: {
                        navigationState.destinationAddress = ""
                        showSuggestions = false
                        addressSuggestions = []
                        enhancedSearchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showSuggestions ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .padding(.horizontal, 8)
            
            // Enhanced Suggestions List
            if showSuggestions && !enhancedSearchResults.isEmpty {
                enhancedSuggestionsList
            }
        }
    }
    
    private var enhancedSuggestionsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(enhancedSearchResults) { result in
                    Button(action: {
                        selectSuggestion(result.completion)
                    }) {
                        HStack(spacing: 12) {
                            // Location Icon
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 20))
                            }
                            
                            // Address Information
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.completion.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if !result.completion.subtitle.isEmpty {
                                    Text(result.completion.subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                // Distance and Time Info
                                HStack(spacing: 12) {
                                    if result.isCalculating {
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                            Text("Calculating...")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    } else if let distance = result.distance, let time = result.travelTime {
                                        // Distance Badge
                                        HStack(spacing: 4) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 10))
                                            Text(DistanceFormatterHelper.string(for: distance, useKilometers: useKilometers))
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                        
                                        // Time Badge
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock.fill")
                                                .font(.system(size: 10))
                                            Text(formatTravelTime(time))
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .foregroundColor(.green)
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Chevron
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                    }
                    .accessibilityLabel(buildAccessibilityLabel(for: result))
                    
                    if result.id != enhancedSearchResults.last?.id {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
        }
        .frame(maxHeight: 320)
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    
    private func updateEnhancedSearchResults(from suggestions: [MKLocalSearchCompletion]) {
        guard let userLocation = tripManager.userLocation else {
            enhancedSearchResults = suggestions.map { EnhancedSearchResult(completion: $0) }
            return
        }
        
        // Cancel any existing search tasks
        for task in activeSearchTasks.values {
            task.cancel()
        }
        activeSearchTasks.removeAll()
        
        // Initialize results with calculating state
        enhancedSearchResults = suggestions.map {
            EnhancedSearchResult(completion: $0, isCalculating: true)
        }
        
        // Limit to first 5 suggestions to avoid overwhelming the API
        let limitedSuggestions = Array(suggestions.prefix(5))
        
        // Calculate distance and time for each suggestion with delay
        for (index, completion) in limitedSuggestions.enumerated() {
            let resultId = enhancedSearchResults[index].id
            
            let task = Task {
                // Stagger requests to avoid rate limiting (200ms delay between each)
                try? await Task.sleep(nanoseconds: UInt64(index) * 200_000_000)
                
                guard !Task.isCancelled else { return }
                
                await calculateRouteForSuggestion(completion: completion, index: index, resultId: resultId, userLocation: userLocation)
            }
            
            activeSearchTasks[resultId] = task
        }
    }

    private func calculateRouteForSuggestion(completion: MKLocalSearchCompletion, index: Int, resultId: UUID, userLocation: CLLocationCoordinate2D) async {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            
            guard !Task.isCancelled,
                  let mapItem = response.mapItems.first else {
                await MainActor.run {
                    if let idx = enhancedSearchResults.firstIndex(where: { $0.id == resultId }) {
                        enhancedSearchResults[idx].isCalculating = false
                    }
                }
                return
            }
            
            // Calculate route
            let sourcePlacemark = MKPlacemark(coordinate: userLocation)
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: sourcePlacemark)
            request.destination = mapItem
            request.transportType = .automobile
            
            let directions = MKDirections(request: request)
            
            do {
                let routeResponse = try await directions.calculate()
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    if let idx = enhancedSearchResults.firstIndex(where: { $0.id == resultId }),
                       let route = routeResponse.routes.first {
                        enhancedSearchResults[idx].distance = route.distance / 1609.34
                        enhancedSearchResults[idx].travelTime = route.expectedTravelTime
                        enhancedSearchResults[idx].isCalculating = false
                    }
                }
            } catch {
                // Route calculation failed, just show location without distance/time
                await MainActor.run {
                    if let idx = enhancedSearchResults.firstIndex(where: { $0.id == resultId }) {
                        enhancedSearchResults[idx].isCalculating = false
                    }
                }
            }
        } catch {
            // Search failed, just show location without distance/time
            await MainActor.run {
                if let idx = enhancedSearchResults.firstIndex(where: { $0.id == resultId }) {
                    enhancedSearchResults[idx].isCalculating = false
                }
            }
        }
    }
    
    private func handleStepChange() {
            hasSpokenFinalReminder = false
            speakCurrentStep(reminder: false)
        }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
            if newPhase == .active && isTripStarted {
                showBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showBanner = false
                    }
                }
            }
        }
    
    private var suggestionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(addressSuggestions, id: \.self) { suggestion in
                    Button(action: {
                        selectSuggestion(suggestion)
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
                    .accessibilityLabel("\(suggestion.title), \(suggestion.subtitle)")
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
        }
        .frame(maxHeight: 90)
        .padding(.horizontal, 8)
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.basedOnSize)
    }
    
    // MARK: - Helper Functions
    
    private func formatTravelTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "< 1 min"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes) min"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(minutes) min"
        }
    }

    private func buildAccessibilityLabel(for result: EnhancedSearchResult) -> String {
        var label = "\(result.completion.title), \(result.completion.subtitle)"
        
        if let distance = result.distance, let time = result.travelTime {
            let distStr = DistanceFormatterHelper.string(for: distance, useKilometers: useKilometers)
            let timeStr = formatTravelTime(time)
            label += ". Distance: \(distStr), Travel time: \(timeStr)"
        }
        
        return label
    }
    
    private func getMapType() -> MKMapType {
        switch selectedMapStyle {
        case 1: return .satellite
        case 2: return .hybrid
        case 3: return .mutedStandard
        default: return .standard
        }
    }
    
    private var coordinateString: String {
        guard let coord = navigationState.destinationCoordinate else { return "" }
        return String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
    }
    
    private func handleLocationUpdate() {
        guard isTripStarted else { return }
        checkStepProximity()
        updateRemainingMiles()
        checkOffRouteAndReroute()
        checkSpeedLimit() // NEW
    }

    private func checkSpeedLimit() {
        guard speedLimitWarningEnabled else {
            showSpeedWarning = false
            return
        }
        
        // Get current speed from TripManager
        let currentSpeedMPH = tripManager.currentSpeed
        
        if currentSpeedMPH > speedLimitThreshold {
            if !showSpeedWarning {
                showSpeedWarning = true
                provideFeedback(.heavy)
                
                // Optional: Speak warning if not muted
                if !isMuted {
                    let utterance = AVSpeechUtterance(string: "Speed limit exceeded")
                    utterance.rate = 0.5
                    speechSynthesizer.speak(utterance)
                }
            }
        } else {
            showSpeedWarning = false
        }
    }
    
    private func handleAddressChange(_ newValue: String) {
        selectedSuggestion = nil
        debounceWorkItem?.cancel()
        
        if newValue.isEmpty {
            showSuggestions = false
            addressSuggestions = []
            enhancedSearchResults = []
        } else {
            showSuggestions = true
            let work = DispatchWorkItem {
                searchCompleter.updateQuery(newValue)
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }
    
    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        provideFeedback(.light)
        selectedSuggestion = suggestion
        showSuggestions = false
        addressSuggestions = []
        navigationState.destinationAddress = suggestion.title + (suggestion.subtitle.isEmpty ? "" : ", \(suggestion.subtitle)")
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        searchCompletionAndShowRoute(completion: suggestion)
    }
    
    private func selectFavorite(_ address: String) {
        provideFeedback(.light)
        navigationState.destinationAddress = address
        selectedSuggestion = nil
        geocodeAndShowRoute()
        showFavoritesSheet = false
    }
    
    private func startTrip() {
        isTripStarted = true
        tripManager.startTrip()
        showAddressPanel = false
        showSuggestions = false
        addressSuggestions = []
        announceTrip(started: true)
    }
    
    private func performEndTrip() {
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
        announceTrip(started: false)
    }
    
    private func moveToStep(_ index: Int) {
        guard index >= 0 && index < navigationState.navigationSteps.count else { return }
        navigationState.currentStepIndex = index
        hasSpokenFinalReminder = false
    }
    
    private func calculateDistanceToStep(_ step: MKRoute.Step) -> String {
        guard let userLoc = tripManager.userLocation else { return "" }
        
        let stepCoord: CLLocationCoordinate2D = {
            if step.polyline.pointCount > 0 {
                return step.polyline.coordinate
            } else {
                return navigationState.destinationCoordinate ?? userLoc
            }
        }()
        
        let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let stepCL = CLLocation(latitude: stepCoord.latitude, longitude: stepCoord.longitude)
        let distance = userCL.distance(from: stepCL)
        
        if distance <= 300 * 0.3048 {
            let feet = Int(distance * 3.28084)
            return "In \(feet) ft"
        } else {
            let miles = distance / 1609.34
            return "In \(DistanceFormatterHelper.string(for: miles, useKilometers: useKilometers))"
        }
    }
    
    private func geocodeAndShowRoute() {
        guard !navigationState.destinationAddress.isEmpty else { return }
        
        isCalculatingRoute = true
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(navigationState.destinationAddress) { placemarks, error in
            DispatchQueue.main.async {
                isCalculatingRoute = false
                
                if let error = error {
                    routeErrorMessage = "Could not find address: \(error.localizedDescription)"
                    showingRouteError = true
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let destinationLoc = placemark.location,
                      let userCoordinate = tripManager.userLocation else {
                    routeErrorMessage = "Unable to determine location. Please try a different address."
                    showingRouteError = true
                    return
                }
                
                navigationState.destinationCoordinate = destinationLoc.coordinate
                createRoute(from: userCoordinate, to: destinationLoc.coordinate)
            }
        }
    }
    
    private func searchCompletionAndShowRoute(completion: MKLocalSearchCompletion) {
        isCalculatingRoute = true
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            DispatchQueue.main.async {
                isCalculatingRoute = false
                
                if let error = error {
                    routeErrorMessage = "Search failed: \(error.localizedDescription)"
                    showingRouteError = true
                    return
                }
                
                guard let mapItem = response?.mapItems.first,
                      let userCoordinate = tripManager.userLocation else {
                    routeErrorMessage = "Unable to find destination."
                    showingRouteError = true
                    return
                }
                
                navigationState.destinationCoordinate = mapItem.placemark.coordinate
                navigationState.destinationAddress = completion.title + (completion.subtitle.isEmpty ? "" : ", \(completion.subtitle)")
                createRoute(from: userCoordinate, to: mapItem.placemark.coordinate)
            }
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
            DispatchQueue.main.async {
                if let error = error {
                    routeErrorMessage = "Route calculation failed: \(error.localizedDescription)"
                    showingRouteError = true
                    return
                }
                
                guard let route = response?.routes.first else {
                    routeErrorMessage = "No route available. Please try a different destination."
                    showingRouteError = true
                    return
                }
                
                navigationState.route = route
                navigationState.estimatedTravelTime = route.expectedTravelTime
                navigationState.routeDistanceMiles = route.distance / 1609.34
                navigationState.navigationSteps = route.steps.filter { !$0.instructions.isEmpty }
                navigationState.currentStepIndex = 0
                updateRemainingMiles()
                announceRouteCalculated(distance: navigationState.routeDistanceMiles)
            }
        }
    }
    
    private func checkStepProximity() {
        guard navigationState.currentStepIndex < navigationState.navigationSteps.count,
              let userLoc = tripManager.userLocation else { return }
        
        let step = navigationState.navigationSteps[navigationState.currentStepIndex]
        let stepLocation: CLLocationCoordinate2D
        if step.polyline.pointCount > 0 {
            stepLocation = step.polyline.coordinate
        } else {
            stepLocation = navigationState.destinationCoordinate ?? userLoc
        }
        
        let user = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let stepCL = CLLocation(latitude: stepLocation.latitude, longitude: stepLocation.longitude)
        let distance = user.distance(from: stepCL)
        
        if distance < 30 {
            if !hasSpokenFinalReminder {
                speakCurrentStep(reminder: true)
                hasSpokenFinalReminder = true
                provideFeedback(.medium)
            }
            if navigationState.currentStepIndex < navigationState.navigationSteps.count - 1 {
                navigationState.currentStepIndex += 1
                hasSpokenFinalReminder = false
            }
        }
    }
    
    private func updateRemainingMiles() {
        guard navigationState.route != nil,
              navigationState.currentStepIndex < navigationState.navigationSteps.count,
              let userLoc = tripManager.userLocation else {
            navigationState.remainingMiles = nil
            return
        }
        
        var remainingDistance = 0.0
        for step in navigationState.navigationSteps[navigationState.currentStepIndex...] {
            remainingDistance += step.distance
        }
        
        let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let nextStep = navigationState.navigationSteps[navigationState.currentStepIndex]
        let stepCoord = nextStep.polyline.pointCount > 0 ? nextStep.polyline.coordinate : (navigationState.destinationCoordinate ?? userLoc)
        let stepLocation = CLLocation(latitude: stepCoord.latitude, longitude: stepCoord.longitude)
        let distanceToStep = userLocation.distance(from: stepLocation)
        
        remainingDistance -= nextStep.distance
        remainingDistance += distanceToStep
        navigationState.remainingMiles = remainingDistance / 1609.34
    }
    
    private func clearNavigation() {
        navigationState.reset()
        selectedSuggestion = nil
        lastSpokenStepIndex = nil
        hasSpokenFinalReminder = false
        speechSynthesizer.stopSpeaking(at: .immediate)
        showSuggestions = false
        addressSuggestions = []
        announceNavigationCleared()
    }
    
    private func closestDistanceToRoute(from location: CLLocation) -> CLLocationDistance? {
        guard let polyline = navigationState.route?.polyline else { return nil }
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
        guard isTripStarted,
              navigationState.route != nil,
              let userLoc = tripManager.userLocation else { return }
        
        let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        guard let minDist = closestDistanceToRoute(from: userCL) else { return }
        
        if minDist > 40 {
            let now = Date()
            if navigationState.isRerouting { return }
            if let last = navigationState.lastRerouteTime, now.timeIntervalSince(last) < 10 { return }
            
            navigationState.isRerouting = true
            navigationState.lastRerouteTime = now
            provideFeedback(.heavy)
            rerouteFromCurrentLocation()
        }
    }
    
    private func rerouteFromCurrentLocation() {
        guard let userCoordinate = tripManager.userLocation,
              let destination = navigationState.destinationCoordinate else {
            navigationState.isRerouting = false
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
                    navigationState.route = newRoute
                    navigationState.estimatedTravelTime = newRoute.expectedTravelTime
                    navigationState.routeDistanceMiles = newRoute.distance / 1609.34
                    navigationState.navigationSteps = newRoute.steps.filter { !$0.instructions.isEmpty }
                    navigationState.currentStepIndex = 0
                    updateRemainingMiles()
                    announceReroute()
                }
                navigationState.isRerouting = false
            }
        }
    }
    
    private func speakCurrentStep(reminder: Bool = false) {
        guard isTripStarted else { return }
        guard !isMuted else { return }
        guard navigationState.currentStepIndex < navigationState.navigationSteps.count else { return }
        
        let step = navigationState.navigationSteps[navigationState.currentStepIndex]
        let instruction = step.instructions
        guard !instruction.isEmpty else { return }
        
        if !reminder && lastSpokenStepIndex == navigationState.currentStepIndex {
            return
        }
        
        var spokenInstruction: String
        
        if reminder {
            spokenInstruction = instruction
        } else {
            if let userLoc = tripManager.userLocation {
                let stepCoord: CLLocationCoordinate2D = {
                    if step.polyline.pointCount > 0 {
                        return step.polyline.coordinate
                    } else {
                        return navigationState.destinationCoordinate ?? userLoc
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
        
        if !navigationVoiceIdentifier.isEmpty,
           let customVoice = AVSpeechSynthesisVoice(identifier: navigationVoiceIdentifier) {
            utterance.voice = customVoice
        } else {
            utterance.voice = getPreferredNavigationVoice()
        }
        
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
        
        if !reminder {
            lastSpokenStepIndex = navigationState.currentStepIndex
        }
    }
    
    private func getPreferredNavigationVoice() -> AVSpeechSynthesisVoice? {
        let preferredVoiceIdentifiers = [
            "com.apple.ttsbundle.siri_female_en-US_compact",
            "com.apple.ttsbundle.siri_female_en-US"
        ]
        
        for id in preferredVoiceIdentifiers {
            if let voice = AVSpeechSynthesisVoice(identifier: id) {
                return voice
            }
        }
        
        if let samantha = AVSpeechSynthesisVoice(identifier: "com.apple.voice.super-compact.en-US.Samantha") {
            return samantha
        }
        
        if let usVoice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "en-US" }) {
            return usVoice
        }
        
        let lang = Locale.preferredLanguages.first ?? "en-US"
        return AVSpeechSynthesisVoice(language: lang)
    }
    
    // MARK: - Accessibility Announcements
    
    private func announceTrip(started: Bool) {
        let message = started ? "Trip started" : "Trip ended"
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    private func announceRouteCalculated(distance: Double?) {
        guard let distance = distance else { return }
        let distStr = DistanceFormatterHelper.string(for: distance, useKilometers: useKilometers)
        UIAccessibility.post(notification: .announcement, argument: "Route calculated. Distance: \(distStr)")
    }
    
    private func announceNavigationCleared() {
        UIAccessibility.post(notification: .announcement, argument: "Navigation cleared")
    }
    
    private func announceReroute() {
        UIAccessibility.post(notification: .announcement, argument: "Route recalculated")
    }
    
    private func announceVoiceStatus() {
        let message = isMuted ? "Voice guidance muted" : "Voice guidance enabled"
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    // MARK: - Haptic Feedback
    
    private func provideFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
