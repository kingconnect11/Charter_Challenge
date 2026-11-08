import Foundation
import CoreLocation

// MARK: - Maritime Router
struct MaritimeRouter {
    
    // Calculate maritime route with waypoints to avoid land
    static func calculateRoute(from origin: Port, to destination: Port) -> MaritimeRoute {
        let distanceNM = PortRegistry.distance(from: origin, to: destination)
        
        // For short coastal routes (< 100 NM), use coastal waypoints
        if distanceNM < 100 {
            return calculateCoastalRoute(from: origin, to: destination)
        }
        
        // For medium routes (100-500 NM), use offshore waypoints
        if distanceNM < 500 {
            return calculateOffshoreRoute(from: origin, to: destination)
        }
        
        // For long ocean routes (> 500 NM), use great circle with waypoints
        return calculateOceanRoute(from: origin, to: destination)
    }
    
    // Convert CLLocationCoordinate2D array to RouteWaypoint array
    private static func waypointsFromCoordinates(_ coords: [CLLocationCoordinate2D]) -> [RouteWaypoint] {
        coords.map { RouteWaypoint(coordinate: $0) }
    }
    
    // Coastal route: Stay close to shore but offshore
    private static func calculateCoastalRoute(from origin: Port, to destination: Port) -> MaritimeRoute {
        var waypoints: [CLLocationCoordinate2D] = []
        
        // Add origin
        waypoints.append(origin.coordinate)
        
        // Calculate bearing
        let bearing = calculateBearing(from: origin.coordinate, to: destination.coordinate)
        let distance = PortRegistry.distance(from: origin, to: destination)
        
        // For coastal routes, add 1-2 waypoints offshore
        if distance > 30 {
            // Add waypoint 20% along route, 5-10 NM offshore
            let midProgress = 0.2
            let midLat = origin.latitude + (destination.latitude - origin.latitude) * midProgress
            let midLon = origin.longitude + (destination.longitude - origin.longitude) * midProgress
            
            // Offset perpendicular to route (offshore)
            let offsetDistance = 0.15 // ~8.7 NM in degrees (rough approximation)
            let perpendicularBearing = bearing + 90.0 // Perpendicular to route
            
            let offsetLat = midLat + offsetDistance * cos(perpendicularBearing * .pi / 180.0)
            let offsetLon = midLon + offsetDistance * sin(perpendicularBearing * .pi / 180.0)
            
            waypoints.append(CLLocationCoordinate2D(latitude: offsetLat, longitude: offsetLon))
            
            // Add second waypoint 80% along if route is long enough
            if distance > 60 {
                let secondProgress = 0.8
                let secondLat = origin.latitude + (destination.latitude - origin.latitude) * secondProgress
                let secondLon = origin.longitude + (destination.longitude - origin.longitude) * secondProgress
                
                let secondOffsetLat = secondLat + offsetDistance * cos(perpendicularBearing * .pi / 180.0)
                let secondOffsetLon = secondLon + offsetDistance * sin(perpendicularBearing * .pi / 180.0)
                
                waypoints.append(CLLocationCoordinate2D(latitude: secondOffsetLat, longitude: secondOffsetLon))
            }
        }
        
        // Add destination
        waypoints.append(destination.coordinate)
        
        return MaritimeRoute(waypoints: waypointsFromCoordinates(waypoints), totalDistanceNM: distance)
    }
    
    // Offshore route: Stay further offshore
    private static func calculateOffshoreRoute(from origin: Port, to destination: Port) -> MaritimeRoute {
        var waypoints: [CLLocationCoordinate2D] = []
        
        waypoints.append(origin.coordinate)
        
        let distance = PortRegistry.distance(from: origin, to: destination)
        let bearing = calculateBearing(from: origin.coordinate, to: destination.coordinate)
        
        // Add 2-3 waypoints offshore
        let numWaypoints = distance > 200 ? 3 : 2
        
        for i in 1..<numWaypoints {
            let progress = Double(i) / Double(numWaypoints)
            let lat = origin.latitude + (destination.latitude - origin.latitude) * progress
            let lon = origin.longitude + (destination.longitude - origin.longitude) * progress
            
            // Offset further offshore (15-20 NM)
            let offsetDistance = 0.25 // ~14.5 NM
            let perpendicularBearing = bearing + 90.0
            
            let offsetLat = lat + offsetDistance * cos(perpendicularBearing * .pi / 180.0)
            let offsetLon = lon + offsetDistance * sin(perpendicularBearing * .pi / 180.0)
            
            waypoints.append(CLLocationCoordinate2D(latitude: offsetLat, longitude: offsetLon))
        }
        
        waypoints.append(destination.coordinate)
        
        return MaritimeRoute(waypoints: waypointsFromCoordinates(waypoints), totalDistanceNM: distance)
    }
    
    // Ocean route: Great circle with strategic waypoints
    private static func calculateOceanRoute(from origin: Port, to destination: Port) -> MaritimeRoute {
        var waypoints: [CLLocationCoordinate2D] = []
        
        waypoints.append(origin.coordinate)
        
        let distance = PortRegistry.distance(from: origin, to: destination)
        
        // For very long routes, add waypoints at 25%, 50%, 75%
        let waypointProgresses = [0.25, 0.5, 0.75]
        
        for progress in waypointProgresses {
            // Use great circle interpolation
            let lat = origin.latitude + (destination.latitude - origin.latitude) * progress
            let lon = origin.longitude + (destination.longitude - origin.longitude) * progress
            
            waypoints.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        waypoints.append(destination.coordinate)
        
        return MaritimeRoute(waypoints: waypointsFromCoordinates(waypoints), totalDistanceNM: distance)
    }
    
    // Calculate bearing between two coordinates
    private static func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let dLon = (to.longitude - from.longitude) * .pi / 180.0
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        let bearing = atan2(y, x) * 180.0 / .pi
        return (bearing + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
    
    // Calculate position along route at given progress (0.0 to 1.0)
    static func positionAlongRoute(_ route: MaritimeRoute, progress: Double) -> CLLocationCoordinate2D {
        guard route.waypoints.count >= 2 else {
            return route.waypoints.first?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        let clampedProgress = max(0.0, min(1.0, progress))
        let totalSegments = route.waypoints.count - 1
        let progressPerSegment = 1.0 / Double(totalSegments)
        
        // Find which segment we're in
        let segmentIndex = min(Int(clampedProgress / progressPerSegment), totalSegments - 1)
        let segmentProgress = (clampedProgress - Double(segmentIndex) * progressPerSegment) / progressPerSegment
        
        // Interpolate within the segment
        let start = route.waypoints[segmentIndex].coordinate
        let end = route.waypoints[min(segmentIndex + 1, route.waypoints.count - 1)].coordinate
        
        let lat = start.latitude + (end.latitude - start.latitude) * segmentProgress
        let lon = start.longitude + (end.longitude - start.longitude) * segmentProgress
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // Calculate distance remaining along route
    static func distanceRemaining(_ route: MaritimeRoute, progress: Double) -> Double {
        let clampedProgress = max(0.0, min(1.0, progress))
        return route.totalDistanceNM * (1.0 - clampedProgress)
    }
}

// MARK: - Maritime Route
struct MaritimeRoute: Codable, Sendable {
    let waypoints: [RouteWaypoint]
    let totalDistanceNM: Double
    
    var start: CLLocationCoordinate2D {
        waypoints.first?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    var end: CLLocationCoordinate2D {
        waypoints.last?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    var coordinates: [CLLocationCoordinate2D] {
        waypoints.map { $0.coordinate }
    }
}

// MARK: - Route Waypoint
struct RouteWaypoint: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

