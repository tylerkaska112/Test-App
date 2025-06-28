//
//  TripTrackerView.swift
//  waylon
//
//  Created by tyler kaska on 6/26/25.
//

import SwiftUI
import _MapKit_SwiftUI

struct TripTrackerView: View {
    @EnvironmentObject var tripManager: TripManager
    @State private var notes = ""
    @State private var pay = ""
    @State private var tripActive = false
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var startCoordinate: CLLocationCoordinate2D? = nil
    @State private var endCoordinate: CLLocationCoordinate2D? = nil
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default center
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var userLocation: CLLocationCoordinate2D? = nil
    @State private var tripStartTime: Date? = nil
    @State private var tripEndTime: Date? = nil

    var body: some View {
        BackgroundWrapper {
            ScrollView {
                VStack(spacing: 20) {

                    ZStack {
                        Map(coordinateRegion: $region, annotationItems: annotationPoints()) { point in
                            MapMarker(coordinate: point.coordinate, tint: point.color)
                        }
                        .frame(height: 300)

                        if routeCoordinates.count > 1 {
                            MapPolyline(coordinates: routeCoordinates)
                        }
                    }
                    .onAppear {
                        userLocation = tripManager.userLocation
                        if let userLocation = userLocation {
                            region.center = userLocation
                        }
                    }

                    Text("Miles: \(String(format: "%.2f", tripManager.currentDistance))")
                        .font(.largeTitle)
                        .foregroundColor(.white)

                    if tripActive {
                        Button("End Trip") {
                            endCoordinate = tripManager.userLocation
                            tripEndTime = Date()
                            tripActive = false
                            if let end = endCoordinate, let start = startCoordinate, let startTime = tripStartTime, let endTime = tripEndTime {
                                tripManager.endTrip(withNotes: notes, pay: pay, start: start, end: end, route: routeCoordinates, startTime: startTime, endTime: endTime)
                                resetTrip()
                            }
                        }
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                    } else {
                        Button("Start Trip") {
                            tripManager.startTrip()
                            startCoordinate = tripManager.userLocation
                            routeCoordinates = []
                            tripStartTime = Date()
                            tripActive = true
                        }
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                    }

                    TextField("Notes", text: $notes)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

                    TextField("Pay", text: $pay)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }
            }
            .onReceive(tripManager.$userLocation) { newLocation in
                userLocation = newLocation
                if tripActive, let newLocation = newLocation {
                    routeCoordinates.append(newLocation)
                    region.center = newLocation
                }
            }
        }
    }

    private func annotationPoints() -> [MapPoint] {
        var points: [MapPoint] = []
        if let start = startCoordinate {
            points.append(MapPoint(coordinate: start, color: .green))
        }
        if let end = endCoordinate {
            points.append(MapPoint(coordinate: end, color: .red))
        }
        if let user = userLocation {
            points.append(MapPoint(coordinate: user, color: .blue))
        }
        return points
    }

    private func resetTrip() {
        notes = ""
        pay = ""
        startCoordinate = nil
        endCoordinate = nil
        routeCoordinates = []
        tripStartTime = nil
        tripEndTime = nil
    }
}

struct MapPolyline: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.blue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}
