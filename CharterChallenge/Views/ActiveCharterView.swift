import SwiftUI
import MapKit

struct ActiveCharterView: View {
    @EnvironmentObject var gameVM: GameViewModel
    @State private var showingStatusMenu = false
    
    var body: some View {
        ZStack {
            // Map View
            if let charterState = gameVM.gameState.activeCharterState,
               let charter = gameVM.gameState.activeCharters.first(where: { $0.id == charterState.charterId }),
               let vessel = gameVM.gameState.ownedVessels.first(where: { $0.id == charterState.vesselId }) {
                
                ActiveCharterMapView(
                    charter: charter,
                    vessel: vessel,
                    charterState: charterState
                )
                
                // Top Right: Clock Control
                VStack {
                    HStack {
                        Spacer()
                        CharterClockView()
                    }
                    Spacer()
                }
                
                // Right Side: Progress Indicator
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        CharterProgressIndicator(charterState: charterState)
                            .padding(.bottom, 80) // Space above tab bar
                    }
                }
                
                // Bottom Right: Status Menu Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingStatusMenu.toggle()
                            }
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 80) // Space above tab bar
                    }
                }
                
                // Status Pop-out Menu
                if showingStatusMenu {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            StatusMenuView(charterState: charterState)
                                .padding(.trailing, 16)
                                .padding(.bottom, 80)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                Text("No active charter")
                    .foregroundColor(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let charter = gameVM.gameState.activeCharters.first {
                    Text(charter.title)
                        .font(.headline)
                }
            }
        }
    }
}

// MARK: - Active Charter Map View
struct ActiveCharterMapView: View {
    let charter: Charter
    let vessel: Vessel
    let charterState: ActiveCharterState
    @State private var region: MKCoordinateRegion
    
    init(charter: Charter, vessel: Vessel, charterState: ActiveCharterState) {
        self.charter = charter
        self.vessel = vessel
        self.charterState = charterState
        
        // Initialize region based on current position
        let center = CLLocationCoordinate2D(
            latitude: charterState.currentPosition.currentLatitude,
            longitude: charterState.currentPosition.currentLongitude
        )
        _region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        ))
    }
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: mapAnnotations) { item in
            MapAnnotation(coordinate: item.coordinate) {
                if item.isVessel {
                    VesselMovementMarker(vessel: vessel, progress: charterState.currentPosition.progress)
                        .animation(.easeInOut(duration: 0.3), value: charterState.currentPosition.currentLatitude)
                        .animation(.easeInOut(duration: 0.3), value: charterState.currentPosition.currentLongitude)
                } else if item.isPort {
                    PortMarker(port: item.port!, isSelected: false)
                }
            }
        }
        .onChange(of: charterState.currentPosition.currentLatitude) { newLat in
            withAnimation(.easeInOut(duration: 0.3)) {
                updateRegion()
            }
        }
        .onChange(of: charterState.currentPosition.currentLongitude) { newLon in
            withAnimation(.easeInOut(duration: 0.3)) {
                updateRegion()
            }
        }
    }
    
    var originPort: Port? {
        PortRegistry.port(withName: charter.origin)
    }
    
    var destPort: Port? {
        PortRegistry.port(withName: charter.destination)
    }
    
    private func updateRegion() {
        let center = CLLocationCoordinate2D(
            latitude: charterState.currentPosition.currentLatitude,
            longitude: charterState.currentPosition.currentLongitude
        )
        // Keep vessel centered in view
        region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        )
    }
    
    var mapAnnotations: [ActiveCharterAnnotation] {
        var items: [ActiveCharterAnnotation] = []
        
        // Add origin and destination ports
        if let originPort = PortRegistry.port(withName: charter.origin) {
            items.append(ActiveCharterAnnotation(port: originPort))
        }
        if let destPort = PortRegistry.port(withName: charter.destination) {
            items.append(ActiveCharterAnnotation(port: destPort))
        }
        
        // Add vessel at current position (with smooth animation)
        let vesselCoordinate = CLLocationCoordinate2D(
            latitude: charterState.currentPosition.currentLatitude,
            longitude: charterState.currentPosition.currentLongitude
        )
        items.append(ActiveCharterAnnotation(
            vessel: vessel,
            at: vesselCoordinate
        ))
        
        return items
    }
}

struct ActiveCharterAnnotation: Identifiable {
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

struct VesselMovementMarker: View {
    let vessel: Vessel
    let progress: Double
    
    var body: some View {
        VStack {
            Image(systemName: "sailboat.fill")
                .font(.system(size: 30))
                .foregroundColor(.purple)
                .shadow(color: .black.opacity(0.3), radius: 3)
            
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .padding(4)
                .background(Color.purple.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
        }
    }
}

// MARK: - Timeline Control Bar
struct TimelineControlBar: View {
    @EnvironmentObject var gameVM: GameViewModel
    let charterState: ActiveCharterState
    
    var body: some View {
        HStack(spacing: 12) {
            // Pause/Play Button
            Button(action: {
                gameVM.toggleCharterPause()
            }) {
                Image(systemName: charterState.isPaused ? "play.fill" : "pause.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            // Speed Multipliers
            SpeedButton(multiplier: 1.0, current: charterState.speedMultiplier)
            SpeedButton(multiplier: 2.0, current: charterState.speedMultiplier)
            SpeedButton(multiplier: 5.0, current: charterState.speedMultiplier)
            SpeedButton(multiplier: 10.0, current: charterState.speedMultiplier)
            SpeedButton(multiplier: 20.0, current: charterState.speedMultiplier)
            
            Spacer()
            
            // Time Display
            VStack(alignment: .trailing, spacing: 2) {
                Text("Elapsed: \(formatTime(charterState.elapsedTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let charter = gameVM.gameState.activeCharters.first(where: { $0.id == charterState.charterId }) {
                    let remaining = charter.durationDays * 86400 - charterState.elapsedTime
                    Text("Remaining: \(formatTime(remaining))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        return String(format: "%d:%02d", hours, minutes)
    }
}

struct SpeedButton: View {
    @EnvironmentObject var gameVM: GameViewModel
    let multiplier: Double
    let current: Double
    
    var body: some View {
        Button(action: {
            gameVM.setCharterSpeed(multiplier: multiplier)
        }) {
            Text("\(Int(multiplier))x")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(multiplier == current ? .white : .primary)
                .frame(width: 40, height: 32)
                .background(multiplier == current ? Color.blue : Color(.systemGray5))
                .cornerRadius(6)
        }
    }
}

// MARK: - Status Menu View
struct StatusMenuView: View {
    @EnvironmentObject var gameVM: GameViewModel
    let charterState: ActiveCharterState
    @State private var showingEvents = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Charter Status")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            // Weather
            VStack(alignment: .leading, spacing: 4) {
                Text("Weather")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack {
                    Text(charterState.weather.rawValue)
                    Spacer()
                    Text("\(Int(charterState.windSpeed)) kts")
                        .foregroundColor(.secondary)
                }
            }
            
            // Guest Happiness
            VStack(alignment: .leading, spacing: 4) {
                Text("Guest Happiness")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ProgressView(value: charterState.guestHappiness, total: 100)
                    .tint(happinessColor(charterState.guestHappiness))
                Text("\(Int(charterState.guestHappiness))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Staff Stress
            VStack(alignment: .leading, spacing: 4) {
                Text("Staff Stress")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ProgressView(value: charterState.staffStress, total: 100)
                    .tint(stressColor(charterState.staffStress))
                Text("\(Int(charterState.staffStress))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress
            VStack(alignment: .leading, spacing: 4) {
                Text("Route Progress")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ProgressView(value: charterState.currentPosition.progress, total: 1.0)
                    .tint(.blue)
                HStack {
                    Text("\(Int(charterState.currentPosition.progress * 100))% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(charterState.currentPosition.distanceRemaining)) NM remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Crew Info
            if let vessel = gameVM.gameState.ownedVessels.first(where: { $0.id == charterState.vesselId }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Crew")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    let crewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
                    Text("\(crewCount) members assigned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Show high-stress crew
                    let highStressCrew = gameVM.gameState.hiredCrew.filter { crew in
                        vessel.assignedCrew.contains(crew.id) && crew.currentStress > 60
                    }
                    if !highStressCrew.isEmpty {
                        Text("⚠️ \(highStressCrew.count) crew member(s) under high stress")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Divider()
            
            // Events Button
            Button(action: {
                showingEvents.toggle()
            }) {
                HStack {
                    Text("View Events")
                        .font(.subheadline)
                    Spacer()
                    if !gameVM.gameState.charterEvents.isEmpty {
                        Text("(\(gameVM.gameState.charterEvents.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
            }
            .foregroundColor(.blue)
        }
        .padding()
        .frame(width: 280)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .padding(.trailing)
        .sheet(isPresented: $showingEvents) {
            CharterEventsView()
                .environmentObject(gameVM)
        }
    }
    
    private func happinessColor(_ value: Double) -> Color {
        if value >= 80 { return .green }
        if value >= 60 { return .yellow }
        if value >= 40 { return .orange }
        return .red
    }
    
    private func stressColor(_ value: Double) -> Color {
        if value >= 80 { return .red }
        if value >= 60 { return .orange }
        if value >= 40 { return .yellow }
        return .green
    }
}

