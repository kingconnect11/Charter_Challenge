import SwiftUI
import MapKit
import CoreLocation

struct CharterDetailView: View {
    @EnvironmentObject var gameVM: GameViewModel
    let charter: Charter
    @State private var region: MKCoordinateRegion
    
    init(charter: Charter) {
        self.charter = charter
        // Initialize region based on charter origin/destination
        if let originPort = PortRegistry.port(withName: charter.origin),
           let destPort = PortRegistry.port(withName: charter.destination) {
            let centerLat = (originPort.latitude + destPort.latitude) / 2.0
            let centerLon = (originPort.longitude + destPort.longitude) / 2.0
            let latDelta = abs(originPort.latitude - destPort.latitude) * 1.5
            let lonDelta = abs(originPort.longitude - destPort.longitude) * 1.5
            let span = MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.1),
                longitudeDelta: max(lonDelta, 0.1)
            )
            self._region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: span
            ))
        } else {
            self._region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }
    }
    
    var vessel: Vessel? {
        guard let vesselId = charter.assignedVessel else { return nil }
        return gameVM.gameState.ownedVessels.first(where: { $0.id == vesselId })
    }
    
    var charterEvents: [CharterEvent] {
        gameVM.gameState.charterEvents.filter { $0.timestamp <= charter.durationDays * 86400 }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Charter Info Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(charter.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label(charter.origin, systemImage: "location.fill")
                        Image(systemName: "arrow.right")
                        Label(charter.destination, systemImage: "location.fill")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Label("\(Int(ceil(charter.durationDays))) days", systemImage: "calendar")
                        Label("\(charter.guests) guests", systemImage: "person.2")
                        Label("$\(Int(charter.basePay).formatted())", systemImage: "dollarsign.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                
                Divider()
                
                // Map View
                VStack(alignment: .leading, spacing: 8) {
                    Text("Route")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if let originPort = PortRegistry.port(withName: charter.origin),
                       let destPort = PortRegistry.port(withName: charter.destination),
                       let vessel = vessel {
                        
                        CharterRouteMapView(
                            charter: charter,
                            vessel: vessel,
                            origin: originPort,
                            destination: destPort,
                            region: $region
                        )
                        .frame(height: 300)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                
                // Charter Events
                if !charterEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Charter History")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(charterEvents.sorted(by: { $0.timestamp < $1.timestamp })) { event in
                            CharterEventRow(event: event)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Charter Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CharterRouteMapView: View {
    let charter: Charter
    let vessel: Vessel
    let origin: Port
    let destination: Port
    @Binding var region: MKCoordinateRegion
    
    var route: MaritimeRoute? {
        MaritimeRouter.calculateRoute(from: origin, to: destination)
    }
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [origin, destination]) { port in
            MapAnnotation(coordinate: port.coordinate) {
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(port.name == charter.origin ? .green : .red)
                    Text(port.name)
                        .font(.caption2)
                        .padding(4)
                        .background(Color.white)
                        .cornerRadius(4)
                }
            }
        }
        .overlay(
            // Draw route if available
            Group {
                if let route = route {
                    Path { path in
                        let coords = route.coordinates
                        guard !coords.isEmpty else { return }
                        
                        // Convert coordinates to screen points (simplified)
                        // In a real implementation, you'd use MapKit's overlay rendering
                        let first = coords[0]
                        path.move(to: CGPoint(x: 0, y: 0))
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
            }
        )
    }
}

struct CharterEventRow: View {
    let event: CharterEvent
    
    var icon: String {
        switch event.type {
        case .guestPraise: return "star.fill"
        case .guestComplaint: return "exclamationmark.triangle.fill"
        case .incident: return "exclamationmark.circle.fill"
        case .weatherChange: return "cloud.fill"
        case .equipmentFailure: return "wrench.fill"
        case .smoothSailing: return "checkmark.circle.fill"
        case .crewIssue: return "person.2.fill"
        }
    }
    
    var iconColor: Color {
        switch event.type {
        case .guestPraise, .smoothSailing: return .green
        case .guestComplaint, .incident: return .red
        case .weatherChange, .equipmentFailure, .crewIssue: return .orange
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.message)
                    .font(.subheadline)
                
                if event.impact.guestHappinessDelta != 0 || event.impact.staffStressDelta != 0 {
                    HStack(spacing: 12) {
                        if event.impact.guestHappinessDelta != 0 {
                            Label("\(event.impact.guestHappinessDelta > 0 ? "+" : "")\(Int(event.impact.guestHappinessDelta))%", systemImage: "heart.fill")
                                .font(.caption)
                                .foregroundColor(event.impact.guestHappinessDelta > 0 ? .green : .red)
                        }
                        if event.impact.staffStressDelta != 0 {
                            Label("\(event.impact.staffStressDelta > 0 ? "+" : "")\(Int(event.impact.staffStressDelta))%", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(event.impact.staffStressDelta > 0 ? .red : .green)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

