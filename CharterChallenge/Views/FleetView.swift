import SwiftUI

struct FleetView: View {
    @EnvironmentObject var gameVM: GameViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("View", selection: $selectedTab) {
                Text("Store").tag(0)
                Text("My Fleet").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                // Store View
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(gameVM.vesselCatalog) { vessel in
                            VesselCatalogCard(vessel: vessel)
                        }
                    }
                    .padding()
                }
            } else {
                // My Fleet
                if gameVM.gameState.ownedVessels.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "sailboat")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No vessels in your fleet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Purchase a vessel from the Store")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(gameVM.gameState.ownedVessels) { vessel in
                                NavigationLink(destination: VesselDetailView(vessel: vessel)) {
                                    OwnedVesselCard(vessel: vessel)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Fleet")
    }
}

struct VesselCatalogCard: View {
    @EnvironmentObject var gameVM: GameViewModel
    let vessel: Vessel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Vessel Image
            if let imageName = vessel.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Image(systemName: "sailboat")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vessel.name)
                        .font(.headline)
                    Text(vessel.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                Spacer()
                Text("$\(Int(vessel.purchasePrice).formatted())")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            Divider()

            HStack(spacing: 20) {
                StatBadge(icon: "ruler", value: "\(vessel.lengthFeet)'")
                StatBadge(icon: "speedometer", value: "\(Int(vessel.speedKnots)) kts")
                StatBadge(icon: "person.2", value: "\(vessel.guestCapacity)")
                if vessel.isExplorer {
                    StatBadge(icon: "map", value: "Explorer", color: .orange)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Crew: \(vessel.crewMin)-\(vessel.crewMax)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Daily: $\(Int(vessel.dailyOpex))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    gameVM.purchaseVessel(vessel)
                }) {
                    Text("Purchase")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

struct OwnedVesselCard: View {
    @EnvironmentObject var gameVM: GameViewModel
    let vessel: Vessel

    var assignedCaptainName: String {
        if let captainId = vessel.assignedCaptain,
           let captain = gameVM.gameState.hiredCaptains.first(where: { $0.id == captainId }) {
            return captain.name
        }
        return "No captain assigned"
    }
    
    var crewCount: Int {
        vessel.assignedCrew.count
    }
    
    var fuelPercentage: Double {
        guard vessel.fuelCapacity > 0 else { return 0.0 }
        return (vessel.currentFuel / vessel.fuelCapacity) * 100.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Vessel Image
            if let imageName = vessel.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Image(systemName: "sailboat")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vessel.name)
                        .font(.headline)
                    Text(vessel.status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor(vessel.status).opacity(0.2))
                        .foregroundColor(statusColor(vessel.status))
                        .cornerRadius(4)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(vessel.currentLocation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Captain
            HStack {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(assignedCaptainName)
                    .font(.subheadline)
            }

            // Crew count
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Crew: \(crewCount)/\(vessel.crewMax)")
                    .font(.subheadline)
                    .foregroundColor(crewCount < vessel.crewMin ? .red : (crewCount >= vessel.crewMax ? .orange : .primary))
            }
            
            // Fuel level
            if vessel.fuelCapacity > 0 {
                HStack {
                    Image(systemName: "fuelpump.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Fuel: \(Int(fuelPercentage))%")
                        .font(.subheadline)
                    Spacer()
                    ProgressView(value: fuelPercentage, total: 100)
                        .frame(width: 60)
                        .tint(fuelPercentage < 20 ? .red : (fuelPercentage < 50 ? .orange : .green))
                }
            }

            // Condition
            HStack {
                Image(systemName: "gauge.medium")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Condition: \(Int(vessel.condition))%")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
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

struct StatBadge: View {
    let icon: String
    let value: String
    var color: Color = .blue

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
    }
}
