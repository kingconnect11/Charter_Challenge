import SwiftUI

struct VesselDetailView: View {
    @EnvironmentObject var gameVM: GameViewModel
    let vessel: Vessel
    
    var assignedCaptain: Captain? {
        guard let captainId = vessel.assignedCaptain else { return nil }
        return gameVM.gameState.hiredCaptains.first(where: { $0.id == captainId })
    }
    
    var assignedCrewMembers: [CrewMember] {
        vessel.assignedCrew.compactMap { crewId in
            gameVM.gameState.hiredCrew.first(where: { $0.id == crewId })
        }
    }
    
    var completedCharters: [Charter] {
        gameVM.gameState.completedCharters.filter { $0.assignedVessel == vessel.id }
    }
    
    var fuelPercentage: Double {
        guard vessel.fuelCapacity > 0 else { return 0.0 }
        return (vessel.currentFuel / vessel.fuelCapacity) * 100.0
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Vessel Image
                if let imageName = vessel.imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                } else {
                    Image(systemName: "sailboat")
                        .font(.system(size: 100))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                // Vessel Name and Status
                VStack(alignment: .leading, spacing: 8) {
                    Text(vessel.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(vessel.category.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        
                        Text(vessel.status.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(statusColor(vessel.status).opacity(0.2))
                            .foregroundColor(statusColor(vessel.status))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Specifications
                VStack(alignment: .leading, spacing: 16) {
                    Text("Specifications")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        SpecRow(icon: "ruler", label: "Length", value: "\(vessel.lengthFeet)'")
                        SpecRow(icon: "speedometer", label: "Max Speed", value: "\(Int(vessel.speedKnots)) knots")
                        SpecRow(icon: "gauge", label: "Range", value: "\(vessel.rangeNM) NM")
                        SpecRow(icon: "person.2", label: "Guest Capacity", value: "\(vessel.guestCapacity)")
                        SpecRow(icon: "person.3", label: "Crew", value: "\(vessel.crewMin)-\(vessel.crewMax)")
                        SpecRow(icon: "fork.knife", label: "Galley Grade", value: "\(vessel.galleyGrade)/5")
                        SpecRow(icon: "archivebox", label: "Storage", value: "\(vessel.pantryUnits + vessel.coldStorageUnits) units")
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Current Status
                VStack(alignment: .leading, spacing: 16) {
                    Text("Current Status")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("Location: \(vessel.currentLocation)")
                                .font(.subheadline)
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "gauge.medium")
                                .foregroundColor(conditionColor(vessel.condition))
                            Text("Condition: \(Int(vessel.condition))%")
                                .font(.subheadline)
                            Spacer()
                            ProgressView(value: vessel.condition, total: 100.0)
                                .frame(width: 100)
                                .tint(conditionColor(vessel.condition))
                        }
                        
                        if vessel.fuelCapacity > 0 {
                            HStack {
                                Image(systemName: "fuelpump.fill")
                                    .foregroundColor(fuelPercentage < 20 ? .red : .green)
                                Text("Fuel: \(Int(fuelPercentage))%")
                                    .font(.subheadline)
                                Spacer()
                                ProgressView(value: fuelPercentage, total: 100)
                                    .frame(width: 100)
                                    .tint(fuelPercentage < 20 ? .red : (fuelPercentage < 50 ? .orange : .green))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Assigned Crew
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Assigned Crew")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            gameVM.assignAllAvailableStaffToVessel(vesselId: vessel.id)
                        }) {
                            Text("Assign All Available")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let captain = assignedCaptain {
                        HStack {
                            CrewMemberRow(name: captain.name, role: "Captain", experience: Int(captain.experience))
                            Spacer()
                            Button(action: {
                                gameVM.unassignCaptainFromVessel(vesselId: vessel.id)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        Text("No captain assigned")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    if !assignedCrewMembers.isEmpty {
                        ForEach(assignedCrewMembers, id: \.id) { crew in
                            HStack {
                                CrewMemberRow(name: crew.name, role: crew.role.rawValue, experience: crew.experienceYears)
                                Spacer()
                                Button(action: {
                                    gameVM.unassignCrewFromVessel(crewId: crew.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Text("No crew assigned")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                
                Divider()
                
                // Charter History
                if !completedCharters.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Charter History")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("\(completedCharters.count) completed charter\(completedCharters.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(vessel.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func statusColor(_ status: VesselStatus) -> Color {
        switch status {
        case .moored: return .green
        case .sailing, .shipping: return .blue
        case .charter: return .purple
        case .maintenance: return .orange
        }
    }
    
    func conditionColor(_ condition: Double) -> Color {
        if condition >= 80 { return .green }
        if condition >= 60 { return .orange }
        return .red
    }
}

struct SpecRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct CrewMemberRow: View {
    let name: String
    let role: String
    let experience: Int
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                Text("\(role) • \(experience) years")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

