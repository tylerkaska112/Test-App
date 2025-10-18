import SwiftUI
import MapKit

struct TripSummaryMap: UIViewRepresentable {
    let trip: Trip
    var edgePadding: UIEdgeInsets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
    var showsUserLocation: Bool = false
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.mapType = .standard
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
            
            let mapRect = polyline.boundingMapRect
            mapView.setVisibleMapRect(
                mapRect,
                edgePadding: edgePadding,
                animated: true
            )
        } else if let start = trip.startCoordinate?.clCoordinate {
            let region = MKCoordinateRegion(
                center: start,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            mapView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !annotation.isKind(of: MKUserLocation.self) else {
                return nil
            }
            
            let identifier = "TripPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if annotation.title == "Start" {
                annotationView?.markerTintColor = .systemGreen
                annotationView?.glyphText = "🏁"
            } else if annotation.title == "End" {
                annotationView?.markerTintColor = .systemRed
                annotationView?.glyphText = "🎯"
            }
            
            return annotationView
        }
    }
}


