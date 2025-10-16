//
//  TripRouteScrubbingView.swift
//  waylon
//
//  Created by Tyler Kaska on 10/15/25.
//

import SwiftUI
import MapKit

// MARK: - Route Point Model
struct RoutePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let speed: Double // in m/s
    let distanceFromStart: Double // in miles
    
    var speedMPH: Double {
        speed * 2.23694
    }
    
    var speedKMH: Double {
        speed * 3.6
    }
}

// MARK: - Interactive Trip Map with Scrubbing
struct InteractiveTripMapView: View {
    let trip: Trip
    @Binding var selectedPointIndex: Int?
    @AppStorage("useKilometers") private var useKilometers: Bool = false
    
    @State private var routePoints: [RoutePoint] = []
    @State private var isPlaying: Bool = false
    @State private var playbackSpeed: Double = 1.0
    @State private var playbackTimer: Timer?
    
    var selectedPoint: RoutePoint? {
        guard let index = selectedPointIndex, index < routePoints.count else { return nil }
        return routePoints[index]
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Map View
            ScrubbableMapView(
                trip: trip,
                routePoints: routePoints,
                selectedPointIndex: $selectedPointIndex
            )
            .ignoresSafeArea()
            
            // Overlay Information
            VStack(spacing: 0) {
                if let point = selectedPoint {
                    pointInfoCard(point: point)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Scrubbing Controls
                scrubbingControls
                    .background(.ultraThinMaterial)
                    .cornerRadius(16, corners: [.topLeft, .topRight])
            }
        }
        .onAppear {
            generateRoutePoints()
        }
        .onDisappear {
            stopPlayback()
        }
    }
    
    // MARK: - Point Info Card
    private func pointInfoCard(point: RoutePoint) -> some View {
        VStack(spacing: 12) {
            HStack {
                // Time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(point.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.headline)
                }
                
                Spacer()
                
                // Speed
                VStack(alignment: .center, spacing: 4) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                        Text(formatSpeed(point.speed))
                            .font(.headline)
                    }
                    .foregroundColor(speedColor(point.speedMPH))
                }
                
                Spacer()
                
                // Distance from start
                VStack(alignment: .trailing, spacing: 4) {
                    Text("From Start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDistance(point.distanceFromStart))
                        .font(.headline)
                }
            }
            
            // Progress indicator
            HStack(spacing: 8) {
                Text("Progress:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        
                        if let index = selectedPointIndex, !routePoints.isEmpty {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor)
                                .frame(
                                    width: geometry.size.width * CGFloat(index) / CGFloat(routePoints.count - 1),
                                    height: 6
                                )
                        }
                    }
                }
                .frame(height: 6)
                
                if let index = selectedPointIndex {
                    Text("\(Int((Double(index) / Double(max(routePoints.count - 1, 1))) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 8)
        .padding(.horizontal)
        .padding(.top, 60)
    }
    
    // MARK: - Scrubbing Controls
    private var scrubbingControls: some View {
        VStack(spacing: 16) {
            // Playback controls
            HStack(spacing: 24) {
                Button(action: skipToStart) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .disabled(routePoints.isEmpty)
                
                Button(action: stepBackward) {
                    Image(systemName: "backward.frame.fill")
                        .font(.title2)
                }
                .disabled(selectedPointIndex == nil || selectedPointIndex == 0)
                
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentColor)
                }
                .disabled(routePoints.isEmpty)
                
                Button(action: stepForward) {
                    Image(systemName: "forward.frame.fill")
                        .font(.title2)
                }
                .disabled(selectedPointIndex == nil || selectedPointIndex == routePoints.count - 1)
                
                Button(action: skipToEnd) {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                }
                .disabled(routePoints.isEmpty)
            }
            .padding(.horizontal)
            
            // Scrubber slider
            if !routePoints.isEmpty {
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { Double(selectedPointIndex ?? 0) },
                            set: { selectedPointIndex = Int($0) }
                        ),
                        in: 0...Double(routePoints.count - 1),
                        step: 1
                    )
                    .accentColor(.accentColor)
                    
                    HStack {
                        Text(trip.startTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(trip.endTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            
            // Playback speed control
            HStack {
                Text("Speed:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach([0.5, 1.0, 2.0, 4.0], id: \.self) { speed in
                    Button(action: { playbackSpeed = speed }) {
                        Text("\(speed, specifier: "%.1f")x")
                            .font(.caption)
                            .fontWeight(playbackSpeed == speed ? .bold : .regular)
                            .foregroundColor(playbackSpeed == speed ? .accentColor : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(playbackSpeed == speed ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Playback Controls
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        guard !routePoints.isEmpty else { return }
        
        if selectedPointIndex == nil || selectedPointIndex == routePoints.count - 1 {
            selectedPointIndex = 0
        }
        
        isPlaying = true
        let interval = 0.1 / playbackSpeed // Update every 100ms, adjusted by playback speed
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard let currentIndex = selectedPointIndex else {
                stopPlayback()
                return
            }
            
            if currentIndex < routePoints.count - 1 {
                selectedPointIndex = currentIndex + 1
            } else {
                stopPlayback()
            }
        }
    }
    
    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func stepForward() {
        guard let current = selectedPointIndex, current < routePoints.count - 1 else { return }
        selectedPointIndex = current + 1
    }
    
    private func stepBackward() {
        guard let current = selectedPointIndex, current > 0 else { return }
        selectedPointIndex = current - 1
    }
    
    private func skipToStart() {
        selectedPointIndex = 0
    }
    
    private func skipToEnd() {
        selectedPointIndex = routePoints.count - 1
    }
    
    // MARK: - Route Point Generation
    private func generateRoutePoints() {
        guard !trip.routeCoordinates.isEmpty else { return }
        
        let coordinates = trip.routeCoordinates.map { $0.clCoordinate }
        let totalDuration = trip.endTime.timeIntervalSince(trip.startTime)
        
        var points: [RoutePoint] = []
        var cumulativeDistance: Double = 0
        
        for (index, coord) in coordinates.enumerated() {
            // Calculate timestamp for this point
            let progress = Double(index) / Double(max(coordinates.count - 1, 1))
            let timestamp = trip.startTime.addingTimeInterval(totalDuration * progress)
            
            // Calculate speed between this point and the next
            var speed: Double = 0
            if index < coordinates.count - 1 {
                let currentLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let nextCoord = coordinates[index + 1]
                let nextLocation = CLLocation(latitude: nextCoord.latitude, longitude: nextCoord.longitude)
                
                let distance = currentLocation.distance(from: nextLocation)
                let timeDelta = totalDuration / Double(coordinates.count - 1)
                speed = timeDelta > 0 ? distance / timeDelta : 0
                
                cumulativeDistance += distance / 1609.34 // Convert to miles
            } else if let lastSpeed = points.last?.speed {
                speed = lastSpeed
            }
            
            let point = RoutePoint(
                coordinate: coord,
                timestamp: timestamp,
                speed: speed,
                distanceFromStart: cumulativeDistance
            )
            points.append(point)
        }
        
        routePoints = points
        
        // Start at the beginning
        if !points.isEmpty {
            selectedPointIndex = 0
        }
    }
    
    // MARK: - Helper Functions
    private func formatSpeed(_ speedMS: Double) -> String {
        if useKilometers {
            return String(format: "%.0f km/h", speedMS * 3.6)
        } else {
            return String(format: "%.0f mph", speedMS * 2.23694)
        }
    }
    
    private func formatDistance(_ miles: Double) -> String {
        if useKilometers {
            return String(format: "%.2f km", miles * 1.60934)
        } else {
            return String(format: "%.2f mi", miles)
        }
    }
    
    private func speedColor(_ speedMPH: Double) -> Color {
        if speedMPH < 25 {
            return .green
        } else if speedMPH < 55 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Scrubbable Map View
struct ScrubbableMapView: UIViewRepresentable {
    let trip: Trip
    let routePoints: [RoutePoint]
    @Binding var selectedPointIndex: Int?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        let coordinates = trip.routeCoordinates.map { $0.clCoordinate }
        guard !coordinates.isEmpty else { return }
        
        // Add full route as background
        let fullPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(fullPolyline, level: .aboveRoads)
        
        // Add traveled portion if we have a selected point
        if let selectedIndex = selectedPointIndex, selectedIndex > 0 {
            let traveledCoords = Array(coordinates[0...selectedIndex])
            let traveledPolyline = MKPolyline(coordinates: traveledCoords, count: traveledCoords.count)
            mapView.addOverlay(traveledPolyline, level: .aboveLabels)
        }
        
        // Add current position marker
        if let selectedIndex = selectedPointIndex,
           selectedIndex < routePoints.count {
            let point = routePoints[selectedIndex]
            let annotation = MKPointAnnotation()
            annotation.coordinate = point.coordinate
            annotation.title = "Current Position"
            mapView.addAnnotation(annotation)
            
            // Center map on current position
            let region = MKCoordinateRegion(
                center: point.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        } else {
            // Fit entire route
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            let rect = polyline.boundingMapRect
            let insets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
            mapView.setVisibleMapRect(rect, edgePadding: insets, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            
            let renderer = MKPolylineRenderer(polyline: polyline)
            
            // Check if this is the traveled portion (higher level)
            if overlay.boundingMapRect.size.width < mapView.overlays.first?.boundingMapRect.size.width ?? 0 {
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 6
            } else {
                // Background route
                renderer.strokeColor = .systemGray3
                renderer.lineWidth = 4
            }
            
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "CurrentPosition"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.markerTintColor = .systemBlue
            annotationView?.glyphImage = UIImage(systemName: "location.fill")
            
            return annotationView
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
