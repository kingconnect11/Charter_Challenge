import SwiftUI

struct ChartersView: View {
    @EnvironmentObject var gameVM: GameViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Time Control Panel
            TimeControlPanel()

            Divider()

            // Segmented Control
            Picker("View", selection: $selectedTab) {
                Text("Available").tag(0)
                Text("Active").tag(1)
                Text("Completed").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            if selectedTab == 0 {
                // Available Charters
                if gameVM.gameState.availableCharters.isEmpty {
                    EmptyChartersView(message: "No charters available")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(gameVM.gameState.availableCharters) { charter in
                                AvailableCharterCard(charter: charter)
                            }
                        }
                        .padding()
                    }
                }
            } else if selectedTab == 1 {
                // Active Charters
                if gameVM.gameState.activeCharters.isEmpty {
                    EmptyChartersView(message: "No active charters")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(gameVM.gameState.activeCharters) { charter in
                                ActiveCharterCard(charter: charter)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                // Completed Charters
                if gameVM.gameState.completedCharters.isEmpty {
                    EmptyChartersView(message: "No completed charters")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(gameVM.gameState.completedCharters) { charter in
                                CompletedCharterCard(charter: charter)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Charters")
    }
}

struct TimeControlPanel: View {
    @EnvironmentObject var gameVM: GameViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    gameVM.advanceTime(days: 1)
                }) {
                    HStack {
                        Image(systemName: "forward.fill")
                        Text("+1 Day")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                Button(action: {
                    gameVM.advanceTime(days: 7)
                }) {
                    HStack {
                        Image(systemName: "forward.end.fill")
                        Text("+1 Week")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct AvailableCharterCard: View {
    @EnvironmentObject var gameVM: GameViewModel
    let charter: Charter
    @State private var showingAcceptSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(charter.title)
                        .font(.headline)
                    Text(charter.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(categoryColor(charter.category).opacity(0.2))
                        .foregroundColor(categoryColor(charter.category))
                        .cornerRadius(4)
                }
                Spacer()
            }

            // Route
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(charter.origin)
                    .font(.subheadline)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(charter.destination)
                    .font(.subheadline)
            }

            // Distance (if different ports)
            if charter.origin != charter.destination,
               let originPort = PortRegistry.port(withName: charter.origin),
               let destPort = PortRegistry.port(withName: charter.destination) {
                let distance = PortRegistry.distance(from: originPort, to: destPort)
                HStack(spacing: 4) {
                    Image(systemName: "map")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f NM", distance))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Details
            HStack(spacing: 20) {
                DetailBadge(icon: "person.2", label: "\(charter.guests) guests")
                DetailBadge(icon: "calendar", label: durationText(charter.durationDays))
                DetailBadge(icon: "dollarsign.circle", label: "$\(Int(charter.basePay))")
            }

            if charter.reputationRequired > 0 {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Requires \(charter.reputationRequired) reputation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Accept Button
            Button(action: {
                showingAcceptSheet = true
            }) {
                Text("Review & Accept")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
        .sheet(isPresented: $showingAcceptSheet) {
            AcceptCharterSheet(charter: charter, isPresented: $showingAcceptSheet)
        }
    }

    func durationText(_ days: Double) -> String {
        if days < 1 {
            return "\(Int(days * 24))h"
        } else {
            return "\(Int(ceil(days)))d"
        }
    }

    func categoryColor(_ category: CharterCategory) -> Color {
        switch category {
        case .transport: return .gray
        case .fishing: return .green
        case .adventure: return .orange
        case .luxury: return .purple
        case .vip: return .pink
        case .ultraVIP: return .red
        }
    }
}

struct ActiveCharterCard: View {
    @EnvironmentObject var gameVM: GameViewModel
    let charter: Charter

    var vesselName: String {
        if let vesselId = charter.assignedVessel,
           let vessel = gameVM.gameState.ownedVessels.first(where: { $0.id == vesselId }) {
            return vessel.name
        }
        return "Unknown"
    }

    var daysRemaining: Int {
        if let startDate = charter.startDate {
            let daysPassed = Calendar.current.dateComponents([.day], from: startDate, to: gameVM.gameState.currentDate).day ?? 0
            return max(0, Int(ceil(charter.durationDays)) - daysPassed)
        }
        return Int(ceil(charter.durationDays))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(charter.title)
                        .font(.headline)
                    Text("On \(vesselName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("In Progress")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }

            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text(charter.origin)
                    .font(.subheadline)
                Image(systemName: "arrow.right")
                    .font(.caption)
                Text(charter.destination)
                    .font(.subheadline)
            }

            ProgressView(value: Double(Int(ceil(charter.durationDays)) - daysRemaining), total: charter.durationDays)
                .tint(.purple)

            HStack {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(daysRemaining) days remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if daysRemaining == 0 {
                    Button("Complete Now") {
                        gameVM.completeCharter(charter)
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

struct CompletedCharterCard: View {
    let charter: Charter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(charter.title)
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            HStack(spacing: 8) {
                Text(charter.origin)
                    .font(.caption)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                Text(charter.destination)
                    .font(.caption)
                Spacer()
                if let completionDate = charter.completionDate {
                    Text(completionDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

struct AcceptCharterSheet: View {
    @EnvironmentObject var gameVM: GameViewModel
    let charter: Charter
    @Binding var isPresented: Bool
    @State private var selectedVesselId: String?
    @State private var selectedQuality: ProvisionQuality = .standard
    @State private var showingProvisions = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Charter Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(charter.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack {
                        Text(charter.category.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)

                        Text("$\(Int(charter.basePay)) base pay")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(charter.origin)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                        Text(charter.destination)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))

                // Select Vessel
                List {
                    Section("Select Vessel") {
                        ForEach(gameVM.gameState.ownedVessels.filter { $0.status == .moored && $0.currentLocation == charter.origin }) { vessel in
                            Button(action: {
                                selectedVesselId = vessel.id
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(vessel.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        if let captainId = vessel.assignedCaptain,
                                           let captain = gameVM.gameState.hiredCaptains.first(where: { $0.id == captainId }) {
                                            Text("Captain: \(captain.name)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("No captain assigned")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        let crewCount = vessel.assignedCrew.count
                                        Text("Crew: \(crewCount)/\(vessel.crewMax)")
                                            .font(.caption)
                                            .foregroundColor(crewCount < vessel.crewMin ? .red : .secondary)
                                    }
                                    Spacer()
                                    if selectedVesselId == vessel.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Provisions Section
                    if let vesselId = selectedVesselId,
                       let vessel = gameVM.gameState.ownedVessels.first(where: { $0.id == vesselId }) {
                        Section("Provisions") {
                            Button(action: {
                                showingProvisions = true
                            }) {
                                HStack {
                                    Text("Plan Provisions")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let provisions = gameVM.gameState.vesselProvisions[vesselId] {
                                HStack {
                                    Text("Loaded: \(provisions.loadedUnits) units")
                                        .font(.caption)
                                    Spacer()
                                    Text(provisions.quality.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }

                // Accept Button
                if let vesselId = selectedVesselId {
                    Button(action: {
                        // Create provisions plan if needed
                        var provisionsPlan: ProvisionsPlan? = nil
                        if let vessel = gameVM.gameState.ownedVessels.first(where: { $0.id == vesselId }),
                           let existingProvisions = gameVM.gameState.vesselProvisions[vesselId] {
                            let crewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
                            provisionsPlan = ProvisionsPlan(
                                charterId: charter.id,
                                quality: existingProvisions.quality,
                                requiredUnits: ProvisionsCalculator.calculateRequiredUnits(
                                    for: charter,
                                    guests: charter.guests,
                                    crewCount: crewCount
                                ),
                                loadedUnits: existingProvisions.loadedUnits,
                                unitCost: existingProvisions.unitCost,
                                totalCost: Double(existingProvisions.loadedUnits) * existingProvisions.unitCost
                            )
                        }
                        
                        gameVM.acceptCharter(charter, vesselId: vesselId, provisionsPlan: provisionsPlan)
                        isPresented = false
                    }) {
                        Text("Accept Charter")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Accept Charter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingProvisions) {
                if let vesselId = selectedVesselId,
                   let vessel = gameVM.gameState.ownedVessels.first(where: { $0.id == vesselId }) {
                    ProvisionsPlanningView(charter: charter, vessel: vessel, isPresented: $showingProvisions)
                        .environmentObject(gameVM)
                }
            }
        }
    }
}

struct DetailBadge: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }
}

struct EmptyChartersView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
