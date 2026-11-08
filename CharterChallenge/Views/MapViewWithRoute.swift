import SwiftUI
import MapKit

// Custom annotation class for smooth coordinate updates
class AnimatedPointAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        super.init()
    }
}

// MARK: - Map View with Route Overlay and Annotations
struct MapViewWithRoute: UIViewRepresentable {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let currentPosition: CLLocationCoordinate2D
    let annotations: [ActiveCharterAnnotation]
    let route: MaritimeRoute?
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        mapView.showsUserLocation = false
        
        // Add annotations
        mapView.addAnnotations(annotations.map { annotation in
            if annotation.isVessel {
                return AnimatedPointAnnotation(coordinate: annotation.coordinate, title: "Vessel")
            } else {
                return AnimatedPointAnnotation(coordinate: annotation.coordinate, title: annotation.port?.name)
            }
        })
        
        // Add route overlay
        updateRouteOverlay(mapView: mapView)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Throttle updates to improve performance
        // Only update region if significantly different to avoid flicker
        let currentRegion = mapView.region
        let targetRegion = region
        
        let latDiff = abs(currentRegion.center.latitude - targetRegion.center.latitude)
        let lonDiff = abs(currentRegion.center.longitude - targetRegion.center.longitude)
        
        if latDiff > 0.01 || lonDiff > 0.01 {
            mapView.setRegion(region, animated: true)
        }
        
        // Update annotations - update vessel position smoothly, keep ports stable
        let existingAnnotations = mapView.annotations
        
        // Find and update vessel annotation coordinate smoothly
        if let vesselAnnotation = annotations.first(where: { $0.isVessel }) {
            // Find existing vessel annotation
            if let existingVesselAnnotation = existingAnnotations.first(where: { 
                ($0.title ?? "") == "Vessel"
            }) as? AnimatedPointAnnotation {
                // Only update if coordinate changed significantly (performance optimization)
                let coordDiff = abs(existingVesselAnnotation.coordinate.latitude - vesselAnnotation.coordinate.latitude) +
                               abs(existingVesselAnnotation.coordinate.longitude - vesselAnnotation.coordinate.longitude)
                
                if coordDiff > 0.0001 { // Only update if moved more than ~11 meters
                    // Update coordinate - MapKit will animate this automatically
                    existingVesselAnnotation.coordinate = vesselAnnotation.coordinate
                }
            } else {
                // Add new vessel annotation if it doesn't exist
                let mkAnnotation = AnimatedPointAnnotation(coordinate: vesselAnnotation.coordinate, title: "Vessel")
                mapView.addAnnotation(mkAnnotation)
            }
        }
        
        // Port annotations are stable - only check once, don't update every frame
        // (This is handled in makeUIView, so we skip here for performance)
        
        // Update route overlay only if route changed
        // Check if we need to update overlays
        let currentOverlayCount = mapView.overlays.count
        let expectedOverlayCount = (route != nil && route!.waypoints.count >= 2) ? 2 : 2 // Route + progress
        
        // Only update overlays if count doesn't match or if this is first update
        if currentOverlayCount != expectedOverlayCount || currentOverlayCount == 0 {
            updateRouteOverlay(mapView: mapView)
        } else {
            // Update progress line only (more efficient)
            updateProgressOverlay(mapView: mapView)
        }
    }
    
    // Optimized: Only update progress line, not full route
    private func updateProgressOverlay(mapView: MKMapView) {
        // Remove only progress overlay (keep route overlay)
        let progressOverlays = mapView.overlays.filter { overlay in
            if let polyline = overlay as? MKPolyline {
                let coords = polyline.coordinates
                // Progress line ends at current position, route line ends at destination
                if coords.count >= 2 {
                    let lastCoord = coords[coords.count - 1]
                    let distToCurrent = distanceBetween(lastCoord, currentPosition)
                    let distToDest = distanceBetween(lastCoord, destination)
                    return distToCurrent < distToDest // Progress line is closer to current
                }
            }
            return false
        }
        mapView.removeOverlays(progressOverlays)
        
        // Recreate progress line
        var progressCoordinates: [CLLocationCoordinate2D] = []
        
        if let route = route, route.waypoints.count >= 2 {
            let routeCoords = route.coordinates
            progressCoordinates.append(routeCoords[0]) // Start
            
            // Add waypoints up to current position
            for i in 1..<routeCoords.count {
                let waypoint = routeCoords[i]
                
                if i < routeCoords.count - 1 {
                    let distToCurrent = distanceBetween(currentPosition, waypoint)
                    let distToNext = distanceBetween(currentPosition, routeCoords[i + 1])
                    
                    if distToNext < distToCurrent {
                        progressCoordinates.append(waypoint)
                    } else {
                        break
                    }
                } else {
                    let distToCurrent = distanceBetween(currentPosition, waypoint)
                    let distToPrev = distanceBetween(currentPosition, routeCoords[i - 1])
                    
                    if distToCurrent < distToPrev {
                        progressCoordinates.append(waypoint)
                    }
                }
            }
            
            progressCoordinates.append(currentPosition)
        } else {
            progressCoordinates = [origin, currentPosition]
        }
        
        let progressPolyline = MKPolyline(coordinates: progressCoordinates, count: progressCoordinates.count)
        mapView.addOverlay(progressPolyline)
    }
    
    private func updateRouteOverlay(mapView: MKMapView) {
        // Remove existing route overlays (keep other overlays if any)
        let routeOverlays = mapView.overlays.filter { $0 is MKPolyline }
        mapView.removeOverlays(routeOverlays)
        
        // Create route polyline using waypoints if available, otherwise use straight line
        let routeCoordinates: [CLLocationCoordinate2D]
        if let route = route, route.waypoints.count >= 2 {
            // Use waypoint-based route
            routeCoordinates = route.coordinates
        } else {
            // Fallback to straight line
            routeCoordinates = [origin, destination]
        }
        
        let routePolyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
        mapView.addOverlay(routePolyline)
        
        // Create progress polyline (from origin/start to current position)
        // Build progress line by including waypoints up to current position
        var progressCoordinates: [CLLocationCoordinate2D] = []
        
        if let route = route, route.waypoints.count >= 2 {
            let routeCoords = route.coordinates
            progressCoordinates.append(routeCoords[0]) // Start
            
            // Add waypoints up to and including the segment containing current position
            // We'll include all waypoints before current position, then add current position
            for i in 1..<routeCoords.count {
                let waypoint = routeCoords[i]
                
                // Check if current position is past this waypoint
                // Use simple distance check - if current is closer to next waypoint than to previous, we've passed it
                if i < routeCoords.count - 1 {
                    let distToCurrent = distanceBetween(currentPosition, waypoint)
                    let distToNext = distanceBetween(currentPosition, routeCoords[i + 1])
                    
                    // If we're closer to next waypoint, we've passed this one
                    if distToNext < distToCurrent {
                        progressCoordinates.append(waypoint)
                    } else {
                        // Current position is between previous waypoint and this one
                        break
                    }
                } else {
                    // Last waypoint - check if we've reached it
                    let distToCurrent = distanceBetween(currentPosition, waypoint)
                    let distToPrev = distanceBetween(currentPosition, routeCoords[i - 1])
                    
                    if distToCurrent < distToPrev {
                        // We're closer to destination, include it
                        progressCoordinates.append(waypoint)
                    }
                }
            }
            
            // Always add current position at the end
            progressCoordinates.append(currentPosition)
        } else {
            // Fallback: straight line from origin to current
            progressCoordinates = [origin, currentPosition]
        }
        
        let progressPolyline = MKPolyline(coordinates: progressCoordinates, count: progressCoordinates.count)
        mapView.addOverlay(progressPolyline)
    }
    
    // Helper function to calculate distance between two coordinates (simplified)
    private func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(annotations: annotations)
        coordinator.destinationCoordinate = destination
        return coordinator
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let annotations: [ActiveCharterAnnotation]
        var destinationCoordinate: CLLocationCoordinate2D?
        
        init(annotations: [ActiveCharterAnnotation]) {
            self.annotations = annotations
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                let coords = polyline.coordinates
                
                // Determine if this is the full route or progress line
                // Full route ends at destination, progress line ends at current position
                if coords.count == 2, let dest = destinationCoordinate {
                    let lastCoord = coords[1]
                    let isFullRoute = abs(lastCoord.latitude - dest.latitude) < 0.001 &&
                                     abs(lastCoord.longitude - dest.longitude) < 0.001
                    
                    if isFullRoute {
                        // Full route - green line
                        renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.6)
                        renderer.lineWidth = 4.0
                        renderer.lineDashPattern = nil
                    } else {
                        // Progress line - purple line
                        renderer.strokeColor = UIColor.systemPurple
                        renderer.lineWidth = 5.0
                        renderer.lineDashPattern = nil
                    }
                } else {
                    // Fallback: first overlay is route, second is progress
                    // Use identity comparison since MKOverlay doesn't conform to Equatable
                    let overlayIndex = mapView.overlays.firstIndex(where: { $0 === overlay }) ?? 0
                    if overlayIndex == 0 {
                        renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.6)
                        renderer.lineWidth = 4.0
                    } else {
                        renderer.strokeColor = UIColor.systemPurple
                        renderer.lineWidth = 5.0
                    }
                }
                
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pointAnnotation = annotation as? AnimatedPointAnnotation else { return nil }
            
            // Check if this is a vessel annotation
            if pointAnnotation.title == "Vessel" {
                let identifier = "VesselMarker"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? VesselAnnotationView
                
                // Find matching vessel annotation
                let matchingAnnotation = annotations.first(where: { $0.isVessel })
                
                if annotationView == nil {
                    annotationView = VesselAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.vessel = matchingAnnotation?.vessel
                } else {
                    annotationView?.annotation = annotation
                    // Update vessel if it changed
                    if annotationView?.vessel?.id != matchingAnnotation?.vessel?.id {
                        annotationView?.vessel = matchingAnnotation?.vessel
                    }
                }
                
                annotationView?.canShowCallout = false
                return annotationView
            } else {
                // Port annotation
                let identifier = "PortMarker"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.markerTintColor = .blue
                    annotationView?.glyphImage = UIImage(systemName: "mappin.circle.fill")
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                return annotationView
            }
        }
    }
}

// Custom annotation view for vessel that updates smoothly
class VesselAnnotationView: MKAnnotationView {
    var hostingController: UIHostingController<VesselMovementMarker>?
    var vessel: Vessel? {
        didSet {
            updateView()
        }
    }
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        // Larger frame to accommodate vessel image and arrow
        frame = CGRect(x: 0, y: 0, width: 80, height: 100)
        centerOffset = CGPoint(x: 0, y: -50) // Offset upward to center on vessel position
        canShowCallout = false
    }
    
    private func updateView() {
        guard let vessel = vessel else { return }
        
        // Remove old hosting controller
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        
        // Create new hosting controller with vessel view
        let vesselView = VesselMovementMarker(vessel: vessel, progress: 0.0)
        let hostingController = UIHostingController(rootView: vesselView)
        hostingController.view.backgroundColor = .clear
        
        addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: centerXAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.widthAnchor.constraint(equalToConstant: 80),
            hostingController.view.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        self.hostingController = hostingController
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }
}

// Extension to get coordinates from MKPolyline
extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

