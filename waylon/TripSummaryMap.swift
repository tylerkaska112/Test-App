//
//  TripSummaryMap.swift
//  Photo Tracker
//
//  Created by tyler kaska on 6/26/25.
//


import SwiftUI
import MapKit

struct TripSummaryMap: UIViewRepresentable {
    let trip: Trip

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        if let start = trip.startCoordinate?.clCoordinate {
            let startPin = MKPointAnnotation()
            startPin.coordinate = start
            startPin.title = "Start"
            mapView.addAnnotation(startPin)
        }

        if let end = trip.endCoordinate?.clCoordinate {
            let endPin = MKPointAnnotation()
            endPin.coordinate = end
            endPin.title = "End"
            mapView.addAnnotation(endPin)
        }

        let routeCoords = trip.routeCoordinates.map { $0.clCoordinate }
        if !routeCoords.isEmpty {
            let polyline = MKPolyline(coordinates: routeCoords, count: routeCoords.count)
            mapView.addOverlay(polyline)
            mapView.setVisibleMapRect(polyline.boundingMapRect, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}
