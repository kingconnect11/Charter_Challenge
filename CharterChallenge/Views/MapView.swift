import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var gameVM: GameViewModel
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.2, longitude: -118.0),
        span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
    )
    @State private var selectedPort: Port?
    @State private var selectedVessel: Vessel?

    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $region, annotationItems: mapAnnotations) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    if item.isPort {
                        PortMarker(port: item.port!, isSelected: selectedPort?.id == item.port?.id)
                            .onTapGesture {
                                selectedPort = item.port
                                selectedVessel = nil
                            }
                    } else if item.isVessel {
                        VesselMarker(vessel: item.vessel!)
                            .onTapGesture {
                                selectedVessel = item.vessel
                                selectedPort = nil
                            }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)

            // Info Panel
            VStack {
                Spacer()

                if let port = selectedPort {
                    PortInfoCard(port: port, onClose: {
                        selectedPort = nil
                    })
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let vessel = selectedVessel {
                    VesselInfoCard(vessel: vessel, onClose: {
                        selectedVessel = nil
                    })
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: selectedPort != nil)
            .animation(.spring(), value: selectedVessel != nil)

            // Legend
            VStack {
                HStack {
                    Spacer()
                    MapLegend()
                        .padding()
                }
                Spacer()
            }
        }
        .navigationTitle("Map")
    }

    var mapAnnotations: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []

        // Add ports
        for port in PortRegistry.all {
            items.append(MapAnnotationItem(port: port))
        }

        // Add vessels
        for vessel in gameVM.gameState.ownedVessels {
            if let port = PortRegistry.port(withName: vessel.currentLocation) {
                items.append(MapAnnotationItem(vessel: vessel, at: port.coordinate))
            }
        }

        return items
    }
}

// MARK: - Map Annotation Item
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let port: Port?
    let vessel: Vessel?

    var isPort: Bool { port != nil }
    var isVessel: Bool { vessel != nil }

    init(port: Port) {
        self.coordinate = port.coordinate
        self.port = port
        self.vessel = nil
    }

    init(vessel: Vessel, at coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        self.port = nil
        self.vessel = vessel
    }
}

// MARK: - Port Marker
struct PortMarker: View {
    let port: Port
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: isSelected ? 28 : 24))
                .foregroundColor(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.blue)
                        .shadow(color: .black.opacity(0.3), radius: isSelected ? 6 : 3)
                )

            if isSelected {
                Text(port.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                            .shadow(color: .black.opacity(0.2), radius: 2)
                    )
                    .foregroundColor(.white)
                    .offset(y: 4)
            }
        }
    }
}

// MARK: - Vessel Marker
struct VesselMarker: View {
    let vessel: Vessel

    var statusColor: Color {
        switch vessel.status {
        case .moored: return .green
        case .sailing, .shipping: return .blue
        case .charter: return .purple
        case .maintenance: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "sailboat.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .padding(6)
                .background(
                    Circle()
                        .fill(statusColor)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                )

            Text(vessel.name)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(statusColor)
                        .shadow(color: .black.opacity(0.2), radius: 1)
                )
                .foregroundColor(.white)
        }
    }
}

// MARK: - Port Info Card
struct PortInfoCard: View {
    let port: Port
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(port.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(port.region)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            Text(port.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(String(format: "%.4f°N, %.4f°W", port.latitude, abs(port.longitude)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 10)
        )
    }
}

// MARK: - Vessel Info Card
struct VesselInfoCard: View {
    @EnvironmentObject var gameVM: GameViewModel
    let vessel: Vessel
    let onClose: () -> Void

    var assignedCaptainName: String {
        if let captainId = vessel.assignedCaptain,
           let captain = gameVM.gameState.hiredCaptains.first(where: { $0.id == captainId }) {
            return captain.name
        }
        return "No captain"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vessel.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(vessel.status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor(vessel.status).opacity(0.2))
                        .foregroundColor(statusColor(vessel.status))
                        .cornerRadius(4)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                Label("\(vessel.lengthFeet)'", systemImage: "ruler")
                Label("\(Int(vessel.speedKnots)) kts", systemImage: "speedometer")
                Label(assignedCaptainName, systemImage: "person.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(vessel.currentLocation)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 10)
        )
    }

    func statusColor(_ status: VesselStatus) -> Color {
        switch status {
        case .moored: return .green
        case .sailing, .shipping: return .blue
        case .charter: return .purple
        case .maintenance: return .orange
        }
    }
}

// MARK: - Map Legend
struct MapLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LegendItem(icon: "mappin.circle.fill", color: .blue, label: "Port")
            LegendItem(icon: "sailboat.fill", color: .green, label: "Moored")
            LegendItem(icon: "sailboat.fill", color: .purple, label: "Charter")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 4)
        )
    }
}

struct LegendItem: View {
    let icon: String
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
