import SwiftUI

struct StaffView: View {
    @EnvironmentObject var gameVM: GameViewModel
    @State private var selectedTab = 0
    @State private var selectedCategory: StaffCategory = .captains

    enum StaffCategory: String, CaseIterable {
        case captains = "Captains"
        case crew = "Crew"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category Picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(StaffCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)
            
            // Segmented Control
            Picker("View", selection: $selectedTab) {
                Text("Available").tag(0)
                Text("Hired").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                // Available Staff
                if selectedCategory == .captains {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(gameVM.captainCatalog.filter { !$0.isHired }) { captain in
                                CaptainCard(captain: captain)
                            }
                        }
                        .padding()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(gameVM.crewCatalog.filter { !$0.isHired }) { crew in
                                CrewCard(crew: crew)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                // Hired Staff
                if selectedCategory == .captains {
                    if gameVM.gameState.hiredCaptains.isEmpty {
                        EmptyStaffView(message: "No captains hired", icon: "person.fill")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(gameVM.gameState.hiredCaptains) { captain in
                                    HiredCaptainCard(captain: captain)
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    if gameVM.gameState.hiredCrew.isEmpty {
                        EmptyStaffView(message: "No crew hired", icon: "person.2.fill")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(gameVM.gameState.hiredCrew) { crew in
                                    HiredCrewCard(crew: crew)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .navigationTitle("Staff")
    }
}

struct CaptainCard: View {
    @EnvironmentObject var gameVM: GameViewModel
    let captain: Captain

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(captain.name)
                        .font(.headline)
                    Text("Qualified up to \(captain.qualifiedLengthFeet)'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Quote
            Text("\"\(captain.quote)\"")
                .font(.subheadline)
                .italic()
                .foregroundColor(.secondary)
                .padding(.vertical, 4)

            // Ratings
            HStack(spacing: 16) {
                RatingChip(label: "Personality", value: captain.personality)
                RatingChip(label: "Efficiency", value: captain.efficiency)
                RatingChip(label: "Experience", value: captain.experience)
            }

            Divider()

            // Profile
            Text(captain.profile)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            // Cost and Hire
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day Rate: $\(Int(captain.dayRate))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Signing: $\(Int(captain.signingBonus))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    gameVM.hireCaptain(captain)
                }) {
                    Text("Hire")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(captain.isHired)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

struct HiredCaptainCard: View {
    @EnvironmentObject var gameVM: GameViewModel
    let captain: Captain
    @State private var showingAssignSheet = false

    var assignedVesselName: String {
        if let vesselId = captain.currentVessel,
           let vessel = gameVM.gameState.ownedVessels.first(where: { $0.id == vesselId }) {
            return vessel.name
        }
        return "Unassigned"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(captain.name)
                        .font(.headline)
                    HStack(spacing: 8) {
                        RatingChip(label: "P", value: captain.personality, compact: true)
                        RatingChip(label: "E", value: captain.efficiency, compact: true)
                        RatingChip(label: "X", value: captain.experience, compact: true)
                    }
                }
                Spacer()
            }

            HStack {
                Image(systemName: "sailboat.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(assignedVesselName)
                    .font(.subheadline)
                Spacer()
                Button("Assign") {
                    showingAssignSheet = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
        .sheet(isPresented: $showingAssignSheet) {
            AssignCaptainSheet(captain: captain, isPresented: $showingAssignSheet)
        }
    }
}

struct AssignCaptainSheet: View {
    @EnvironmentObject var gameVM: GameViewModel
    let captain: Captain
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List(gameVM.gameState.ownedVessels) { vessel in
                Button(action: {
                    gameVM.assignCaptainToVessel(captainId: captain.id, vesselId: vessel.id)
                    isPresented = false
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vessel.name)
                            .font(.headline)
                        Text("\(vessel.lengthFeet)' • \(vessel.currentLocation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Assign \(captain.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct RatingChip: View {
    let label: String
    let value: Double
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            if !compact {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(String(format: "%.1f", value))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(ratingColor(value))
        }
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, 2)
        .background(ratingColor(value).opacity(0.2))
        .cornerRadius(4)
    }

    func ratingColor(_ rating: Double) -> Color {
        if rating >= 4.5 {
            return .green
        } else if rating >= 3.5 {
            return .blue
        } else if rating >= 2.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Crew Card
struct CrewCard: View {
    @EnvironmentObject var gameVM: GameViewModel
    let crew: CrewMember

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(crew.name)
                        .font(.headline)
                    Text(crew.role.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Description
            Text(crew.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Skills
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", crew.skillRating))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ratingColor(crew.skillRating))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Experience")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(crew.experienceYears) yrs")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }

            Divider()

            // Cost and Hire
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day Rate: $\(Int(crew.dayRate))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("First week: $\(Int(crew.dayRate * 7))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    gameVM.hireCrew(crew)
                }) {
                    Text("Hire")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(crew.isHired)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
    
    func ratingColor(_ rating: Double) -> Color {
        if rating >= 4.0 {
            return .green
        } else if rating >= 3.0 {
            return .blue
        } else if rating >= 2.0 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Hired Crew Card
struct HiredCrewCard: View {
    @EnvironmentObject var gameVM: GameViewModel
    let crew: CrewMember
    @State private var showingAssignSheet = false

    var assignedVesselName: String {
        if let vesselId = crew.currentVessel,
           let vessel = gameVM.gameState.ownedVessels.first(where: { $0.id == vesselId }) {
            return vessel.name
        }
        return "Unassigned"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(crew.name)
                        .font(.headline)
                    Text(crew.role.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Stress indicator
                if crew.currentStress > 50 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(Int(crew.currentStress))%")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Skill:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", crew.skillRating))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                HStack(spacing: 4) {
                    Text("Exp:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(crew.experienceYears) yrs")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }

            HStack {
                Image(systemName: "sailboat.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(assignedVesselName)
                    .font(.subheadline)
                Spacer()
                Button("Assign") {
                    showingAssignSheet = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
        .sheet(isPresented: $showingAssignSheet) {
            AssignCrewSheet(crew: crew, isPresented: $showingAssignSheet)
        }
    }
}

// MARK: - Assign Crew Sheet
struct AssignCrewSheet: View {
    @EnvironmentObject var gameVM: GameViewModel
    let crew: CrewMember
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List(gameVM.gameState.ownedVessels) { vessel in
                Button(action: {
                    gameVM.assignCrewToVessel(crewId: crew.id, vesselId: vessel.id)
                    isPresented = false
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vessel.name)
                            .font(.headline)
                        Text("\(vessel.lengthFeet)' • \(vessel.currentLocation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Show current crew count
                        let currentCrewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
                        Text("Crew: \(currentCrewCount)/\(vessel.crewMax)")
                            .font(.caption)
                            .foregroundColor(currentCrewCount >= vessel.crewMax ? .red : .secondary)
                    }
                }
            }
            .navigationTitle("Assign \(crew.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Empty Staff View
struct EmptyStaffView: View {
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
