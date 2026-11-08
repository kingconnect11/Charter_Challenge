import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
final class GameViewModel: ObservableObject {
    @Published var gameState: GameState
    @Published var vesselCatalog: [Vessel] = []
    @Published var captainCatalog: [Captain] = []
    @Published var crewCatalog: [CrewMember] = []

    // UI State
    @Published var showingTripSummary: Bool = false
    @Published var currentTripSummary: TripSummary?
    @Published var toastMessage: String?
    @Published var showingActiveCharter: Bool = false
    @Published var isLoading: Bool = true
    @Published var loadingProgress: Double = 0.0
    
    // Active charter simulation timer
    private var charterTimer: Timer?

    init() {
        self.gameState = GameState()
        Task {
            let startTime = Date()
            
            await loadCatalogsWithProgress()
            generateStarterCharters()
            
            // Ensure loading screen shows for at least 5 seconds total
            let minLoadingTime: TimeInterval = 5.0 // 5 seconds
            let elapsed = Date().timeIntervalSince(startTime)
            
            if elapsed < minLoadingTime {
                let remainingTime = minLoadingTime - elapsed
                try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
            }
            
            // Fade out effect - delay before hiding
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds for fade out
            
            isLoading = false
        }
    }
    
    deinit {
        charterTimer?.invalidate()
    }

    // MARK: - Data Loading
    func loadCatalogs() {
        // Load vessels
        if let vessels: [Vessel] = loadJSON(filename: "vessels") {
            vesselCatalog = vessels
            print("✅ Loaded \(vessels.count) vessels")
        } else {
            vesselCatalog = []
            print("❌ Failed to load vessels.json - using empty catalog")
        }
        
        // Load captains
        if var captains: [Captain] = loadJSON(filename: "captains") {
        // Mark all as not hired initially
        captains = captains.map { var c = $0; c.isHired = false; return c }
        captainCatalog = captains
            print("✅ Loaded \(captains.count) captains")
        } else {
            captainCatalog = []
            print("❌ Failed to load captains.json - using empty catalog")
        }
        
        // Load crew
        if var crew: [CrewMember] = loadJSON(filename: "crew") {
            // Mark all as not hired initially
            crew = crew.map { var c = $0; c.isHired = false; c.currentStress = 0.0; return c }
            crewCatalog = crew
            print("✅ Loaded \(crew.count) crew members")
        } else {
            crewCatalog = []
            print("❌ Failed to load crew.json - using empty catalog")
        }
    }
    
    @MainActor
    func loadCatalogsWithProgress() async {
        loadingProgress = 0.0
        
        // Load vessels (33% of progress)
        if let vessels: [Vessel] = loadJSON(filename: "vessels") {
            vesselCatalog = vessels
            print("✅ Loaded \(vessels.count) vessels")
        } else {
            vesselCatalog = []
            print("❌ Failed to load vessels.json - using empty catalog")
        }
        loadingProgress = 0.33
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Load captains (33% more)
        if var captains: [Captain] = loadJSON(filename: "captains") {
            captains = captains.map { var c = $0; c.isHired = false; return c }
            captainCatalog = captains
            print("✅ Loaded \(captains.count) captains")
        } else {
            captainCatalog = []
            print("❌ Failed to load captains.json - using empty catalog")
        }
        loadingProgress = 0.66
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Load crew (remaining progress)
        if var crew: [CrewMember] = loadJSON(filename: "crew") {
            crew = crew.map { var c = $0; c.isHired = false; c.currentStress = 0.0; return c }
            crewCatalog = crew
            print("✅ Loaded \(crew.count) crew members")
        } else {
            crewCatalog = []
            print("❌ Failed to load crew.json - using empty catalog")
        }
        loadingProgress = 1.0
    }

    private func loadJSON<T: Decodable>(filename: String) -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("❌ Could not find \(filename).json in bundle")
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Could not read data from \(filename).json")
            return nil
        }
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
        return decoded
        } catch {
            print("❌ Failed to decode \(filename).json: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type) at \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("   Key not found: \(key) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   Data corrupted at \(context.codingPath): \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            return nil
        }
    }

    // MARK: - Fleet Management
    func purchaseVessel(_ vessel: Vessel) {
        guard gameState.cash >= vessel.purchasePrice else {
            showToast("Insufficient funds. Need $\(Int(vessel.purchasePrice))")
            return
        }

        var ownedVessel = vessel
        ownedVessel.status = .moored
        ownedVessel.currentLocation = "Marina Del Rey"
        ownedVessel.initializeFuel() // Initialize fuel capacity and fill tank

        gameState.cash -= vessel.purchasePrice
        gameState.ownedVessels.append(ownedVessel)
        showToast("Purchased \(vessel.name) for $\(Int(vessel.purchasePrice))")
    }
    
    func setVesselSpeed(vesselId: String, speed: Double) {
        guard let index = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }) else {
            return
        }
        
        let vessel = gameState.ownedVessels[index]
        let performance = vessel.performance
        let clampedSpeed = max(performance.minCruiseSpeed, min(performance.maxCruiseSpeed, speed))
        
        gameState.ownedVessels[index].selectedSpeed = clampedSpeed
    }
    
    func refuelVessel(vesselId: String, at port: Port) -> Bool {
        guard let index = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }) else {
            return false
        }
        
        let vessel = gameState.ownedVessels[index]
        let fuelNeeded = vessel.fuelCapacity - vessel.currentFuel
        let fuelPricePerGallon = port.fuelPrice ?? 4.0 // Default $4/gallon if not specified
        let cost = fuelNeeded * fuelPricePerGallon
        
        guard gameState.cash >= cost else {
            showToast("Insufficient funds for refueling. Need $\(Int(cost))")
            return false
        }
        
        gameState.cash -= cost
        gameState.ownedVessels[index].currentFuel = vessel.fuelCapacity
        showToast("Refueled \(vessel.name) for $\(Int(cost))")
        return true
    }

    // MARK: - Staff Management
    func hireCaptain(_ captain: Captain) {
        guard !captain.isHired else {
            showToast("\(captain.name) is already hired")
            return
        }

        let totalCost = captain.signingBonus
        guard gameState.cash >= totalCost else {
            showToast("Insufficient funds. Need $\(Int(totalCost)) signing bonus")
            return
        }

        var hiredCaptain = captain
        hiredCaptain.isHired = true
        gameState.cash -= totalCost
        gameState.hiredCaptains.append(hiredCaptain)

        // Update catalog
        if let index = captainCatalog.firstIndex(where: { $0.id == captain.id }) {
            captainCatalog[index].isHired = true
        }

        showToast("Hired \(captain.name)")
    }

    func assignCaptainToVessel(captainId: String, vesselId: String) {
        guard let captainIndex = gameState.hiredCaptains.firstIndex(where: { $0.id == captainId }),
              let vesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }) else {
            return
        }

        // Unassign from previous vessel
        if let oldVesselId = gameState.hiredCaptains[captainIndex].currentVessel,
           let oldVesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == oldVesselId }) {
            gameState.ownedVessels[oldVesselIndex].assignedCaptain = nil
        }

        // Assign to new vessel
        gameState.hiredCaptains[captainIndex].currentVessel = vesselId
        gameState.ownedVessels[vesselIndex].assignedCaptain = captainId

        showToast("Assigned \(gameState.hiredCaptains[captainIndex].name) to \(gameState.ownedVessels[vesselIndex].name)")
    }
    
    func unassignCaptainFromVessel(vesselId: String) {
        guard let vesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }),
              let captainId = gameState.ownedVessels[vesselIndex].assignedCaptain,
              let captainIndex = gameState.hiredCaptains.firstIndex(where: { $0.id == captainId }) else {
            return
        }
        
        gameState.ownedVessels[vesselIndex].assignedCaptain = nil
        gameState.hiredCaptains[captainIndex].currentVessel = nil
        
        showToast("Unassigned captain from \(gameState.ownedVessels[vesselIndex].name)")
    }
    
    // MARK: - Crew Management
    func hireCrew(_ crew: CrewMember) {
        guard !crew.isHired else {
            showToast("\(crew.name) is already hired")
            return
        }
        
        guard gameState.cash >= crew.dayRate * 7 else { // Require 1 week pay upfront
            showToast("Insufficient funds. Need $\(Int(crew.dayRate * 7)) for first week")
            return
        }
        
        var hiredCrew = crew
        hiredCrew.isHired = true
        gameState.cash -= crew.dayRate * 7 // First week advance
        gameState.hiredCrew.append(hiredCrew)
        
        // Update catalog
        if let index = crewCatalog.firstIndex(where: { $0.id == crew.id }) {
            crewCatalog[index].isHired = true
        }
        
        showToast("Hired \(crew.name) as \(crew.role.rawValue)")
    }
    
    func assignCrewToVessel(crewId: String, vesselId: String) {
        guard let crewIndex = gameState.hiredCrew.firstIndex(where: { $0.id == crewId }),
              let vesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }) else {
            return
        }
        
        // Unassign from previous vessel
        if let oldVesselId = gameState.hiredCrew[crewIndex].currentVessel,
           let oldVesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == oldVesselId }) {
            gameState.ownedVessels[oldVesselIndex].assignedCrew.removeAll { $0 == crewId }
        }
        
        // Assign to new vessel
        gameState.hiredCrew[crewIndex].currentVessel = vesselId
        if !gameState.ownedVessels[vesselIndex].assignedCrew.contains(crewId) {
            gameState.ownedVessels[vesselIndex].assignedCrew.append(crewId)
        }
        
        showToast("Assigned \(gameState.hiredCrew[crewIndex].name) to \(gameState.ownedVessels[vesselIndex].name)")
    }
    
    func unassignCrewFromVessel(crewId: String) {
        guard let crewIndex = gameState.hiredCrew.firstIndex(where: { $0.id == crewId }) else {
            return
        }
        
        if let vesselId = gameState.hiredCrew[crewIndex].currentVessel,
           let vesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }) {
            gameState.ownedVessels[vesselIndex].assignedCrew.removeAll { $0 == crewId }
        }
        
        gameState.hiredCrew[crewIndex].currentVessel = nil
        showToast("Unassigned \(gameState.hiredCrew[crewIndex].name) from vessel")
    }
    
    func assignAllAvailableStaffToVessel(vesselId: String) {
        guard let vesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }) else {
            return
        }
        
        let vessel = gameState.ownedVessels[vesselIndex]
        var assignedCount = 0
        
        // Assign captain if available and vessel doesn't have one
        if vessel.assignedCaptain == nil {
            if let availableCaptain = gameState.hiredCaptains.first(where: { $0.isHired && $0.currentVessel == nil }) {
                assignCaptainToVessel(captainId: availableCaptain.id, vesselId: vesselId)
                assignedCount += 1
            }
        }
        
        // Assign crew up to max capacity
        let currentCrewCount = vessel.assignedCrew.count
        let remainingSlots = vessel.crewMax - currentCrewCount
        
        if remainingSlots > 0 {
            let availableCrew = gameState.hiredCrew.filter { $0.isHired && $0.currentVessel == nil }
            let crewToAssign = Array(availableCrew.prefix(remainingSlots))
            
            for crew in crewToAssign {
                assignCrewToVessel(crewId: crew.id, vesselId: vesselId)
                assignedCount += 1
            }
        }
        
        if assignedCount > 0 {
            showToast("Assigned \(assignedCount) staff member\(assignedCount == 1 ? "" : "s") to \(vessel.name)")
        } else {
            showToast("No available staff to assign")
        }
    }

    // MARK: - Charter Management
    func generateStarterCharters() {
        // Use charter market generator for dynamic charters
        let newCharters = CharterMarketGenerator.shared.generateCharters(
            for: gameState.currentDate,
            at: PortRegistry.all,
            reputation: gameState.reputation,
            weatherCondition: .sunny
        )
        
        // Add to available charters, avoiding duplicates
        for charter in newCharters {
            if !gameState.availableCharters.contains(where: { $0.id == charter.id }) {
                gameState.availableCharters.append(charter)
            }
        }
    }
    
    func refreshCharters() {
        // Remove expired charters (older than 7 days)
        let calendar = Calendar.current
        gameState.availableCharters = gameState.availableCharters.filter { charter in
            // Keep charters that are still relevant
            return true // For now, keep all charters
        }
        
        // Generate new charters
        generateStarterCharters()
    }

    func acceptCharter(_ charter: Charter, vesselId: String, provisionsPlan: ProvisionsPlan? = nil) {
        guard let vesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }) else {
            showToast("Vessel not found")
            return
        }

        let vessel = gameState.ownedVessels[vesselIndex]

        // Validation
        guard vessel.currentLocation == charter.origin else {
            showToast("Vessel must be at \(charter.origin)")
            return
        }

        guard vessel.assignedCaptain != nil else {
            showToast("Assign a captain to this vessel first")
            return
        }

        guard gameState.reputation >= charter.reputationRequired else {
            showToast("Reputation too low. Need \(charter.reputationRequired)")
            return
        }

        // Load provisions if plan provided
        if let plan = provisionsPlan {
            guard gameState.cash >= plan.totalCost else {
                showToast("Insufficient funds for provisions. Need $\(Int(plan.totalCost))")
                return
            }
            
            gameState.cash -= plan.totalCost
            gameState.vesselProvisions[vesselId] = Provisions(
                quality: plan.quality,
                loadedUnits: plan.loadedUnits,
                unitCost: plan.unitCost
            )
        }

        // Update charter
        if let charterIndex = gameState.availableCharters.firstIndex(where: { $0.id == charter.id }) {
            var activeCharter = gameState.availableCharters[charterIndex]
            activeCharter.status = .inProgress
            activeCharter.assignedVessel = vesselId
            activeCharter.startDate = gameState.currentDate

            gameState.activeCharters.append(activeCharter)
            gameState.availableCharters.remove(at: charterIndex)

            // Update vessel status
            gameState.ownedVessels[vesselIndex].status = .charter
            
            // Initialize active charter state
            initializeActiveCharterState(charter: activeCharter, vesselId: vesselId)

            showToast("Charter accepted! Starting \(charter.title)")
            showingActiveCharter = true
        }
    }
    
    // MARK: - Active Charter Simulation
    func initializeActiveCharterState(charter: Charter, vesselId: String) {
        guard let originPort = PortRegistry.port(withName: charter.origin),
              let destPort = PortRegistry.port(withName: charter.destination) else {
            return
        }
        
        // Calculate maritime route with waypoints
        let route = MaritimeRouter.calculateRoute(from: originPort, to: destPort)
        let distance = route.totalDistanceNM
        
        gameState.activeCharterState = ActiveCharterState(
            charterId: charter.id,
            vesselId: vesselId,
            currentPosition: RoutePosition(
                progress: 0.0,
                currentLatitude: originPort.latitude,
                currentLongitude: originPort.longitude,
                distanceRemaining: distance
            ),
            guestHappiness: 70.0, // Start at 70%
            staffStress: 20.0, // Start at 20%
            weather: .sunny,
            windSpeed: 10.0,
            startTime: Date(),
            elapsedTime: 0,
            isPaused: false,
            speedMultiplier: 1.0,
            route: route,
            riskCheckAccumulator: 0.0,
            eventCheckAccumulator: 0.0
        )
        
        startCharterSimulation()
    }
    
    func startCharterSimulation() {
        charterTimer?.invalidate()
        
        charterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCharterSimulation()
            }
        }
    }
    
    func updateCharterSimulation() {
        guard var charterState = gameState.activeCharterState,
              let charter = gameState.activeCharters.first(where: { $0.id == charterState.charterId }),
              let vessel = gameState.ownedVessels.first(where: { $0.id == charterState.vesselId }),
              let originPort = PortRegistry.port(withName: charter.origin),
              let destPort = PortRegistry.port(withName: charter.destination) else {
            return
        }
        
        if charterState.isPaused {
            return
        }
        
        // Update elapsed time based on speed multiplier
        // At 20x: 6 hours game time = 15 seconds real time
        // At 20x: 1 day (24 hours) game time = 60 seconds real time  
        // Timer runs every 0.1s, so at 20x: 1 day = 600 ticks
        // Each tick at 20x advances: 24 hours / 600 = 0.04 hours = 144 seconds game time
        // At 1x: 144 / 20 = 7.2 seconds game time per tick
        // Formula: timeDelta = 7.2 * speedMultiplier
        let baseSpeedPerTick = 7.2 // seconds game time per tick at 1x speed
        let timeDelta = baseSpeedPerTick * charterState.speedMultiplier
        charterState.elapsedTime += timeDelta
        
        // Store timeDelta for use in updateCharterMetrics to scale changes properly
        let hoursDelta = timeDelta / 3600.0 // Convert seconds to hours
        
        // Calculate progress
        let totalDuration = charter.durationDays * 86400 // Convert days to seconds
        let progress = min(1.0, charterState.elapsedTime / totalDuration)
        
        // Update position using maritime route if available
        let position: CLLocationCoordinate2D
        let distanceRemaining: Double
        
        if let route = charterState.route {
            // Use waypoint-based route
            position = MaritimeRouter.positionAlongRoute(route, progress: progress)
            distanceRemaining = MaritimeRouter.distanceRemaining(route, progress: progress)
        } else {
            // Fallback to straight-line interpolation
            position = CLLocationCoordinate2D(
                latitude: originPort.latitude + (destPort.latitude - originPort.latitude) * progress,
                longitude: originPort.longitude + (destPort.longitude - originPort.longitude) * progress
            )
            let distance = PortRegistry.distance(from: originPort, to: destPort)
            distanceRemaining = distance * (1.0 - progress)
        }
        
        charterState.currentPosition = RoutePosition(
            progress: progress,
            currentLatitude: position.latitude,
            currentLongitude: position.longitude,
            distanceRemaining: distanceRemaining
        )
        
        // Update guest happiness and staff stress (pass timeDelta for proper scaling)
        updateCharterMetrics(&charterState, charter: charter, vessel: vessel, hoursDelta: hoursDelta)
        
        // Update weather (random changes)
        if Int.random(in: 0...100) < 5 { // 5% chance per update
            charterState.weather = [.sunny, .cloudy, .rain, .storm].randomElement() ?? .sunny
            charterState.windSpeed = Double.random(in: 5...25)
        }
        
        // Check for provision package risks (check roughly once per hour of game time)
        charterState.riskCheckAccumulator += hoursDelta
        
        if charterState.riskCheckAccumulator >= 1.0 { // Check once per hour
            charterState.riskCheckAccumulator = 0.0
            
            if let selectedPackages = gameState.vesselProvisionPackages[vessel.id] {
                for packageId in selectedPackages.packages {
                    if let package = ProvisionPackageCatalog.package(withId: packageId),
                       let riskChance = package.riskChance,
                       let riskImpact = package.riskImpact {
                        // Check if risk occurs (1/10 = 0.1 chance)
                        if Double.random(in: 0...1) < riskChance {
                            // Special handling for Security Guard (only triggers if incident occurs)
                            if package.id == "security_guard" && riskImpact > 0 {
                                // Security guard prevents incident - check if incident would have occurred
                                // This is handled in event generation below
                                continue
                            }
                            
                            // Risk occurred
                            charterState.guestHappiness = max(0.0, min(100.0, charterState.guestHappiness + riskImpact))
                            
                            // Create event for risk
                            let event = CharterEvent(
                                id: UUID().uuidString,
                                type: riskImpact > 0 ? .guestPraise : .guestComplaint,
                                message: package.specialCondition ?? "\(package.name) effect: \(riskImpact > 0 ? "+" : "")\(Int(riskImpact))% satisfaction",
                                timestamp: charterState.elapsedTime,
                                impact: CharterEvent.EventImpact(
                                    guestHappinessDelta: riskImpact,
                                    staffStressDelta: 0.0,
                                    costDelta: 0.0
                                )
                            )
                            gameState.charterEvents.append(event)
                            
                            if abs(riskImpact) > 5 {
                                showToast(riskImpact > 0 ? "✨ \(event.message)" : "⚠️ \(event.message)")
                            }
                        }
                    }
                }
            }
        }
        
        // Generate charter events (reduced frequency - check roughly once per hour)
        charterState.eventCheckAccumulator += hoursDelta
        
        if charterState.eventCheckAccumulator >= 1.0 { // Check once per hour
            charterState.eventCheckAccumulator = 0.0
            
            let crewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
            
            // Check for Security Guard incident prevention first
            let hasSecurityGuard = gameState.vesselProvisionPackages[vessel.id]?.packages.contains("security_guard") ?? false
            var incidentPrevented = false
            
            if let event = CharterEventGenerator.generateEvent(
                charterState: charterState,
                vessel: vessel,
                crewCount: crewCount,
                crewStress: charterState.staffStress
            ) {
                // Check if Security Guard prevents negative incident
                if hasSecurityGuard && event.impact.guestHappinessDelta < 0 && Double.random(in: 0...1) < 0.1 {
                    // Security guard prevents incident (1/10 chance)
                    incidentPrevented = true
                    charterState.guestHappiness = max(0.0, min(100.0, charterState.guestHappiness + 50.0))
                    
                    let preventionEvent = CharterEvent(
                        id: UUID().uuidString,
                        type: .guestPraise,
                        message: "Security guard prevented incident: \(event.message)",
                        timestamp: charterState.elapsedTime,
                        impact: CharterEvent.EventImpact(
                            guestHappinessDelta: 50.0,
                            staffStressDelta: -5.0,
                            costDelta: 0.0
                        )
                    )
                    gameState.charterEvents.append(preventionEvent)
                    showToast("🛡️ Security guard prevented incident! +50% satisfaction")
                } else {
                    // Apply event impact normally
                    charterState.guestHappiness = max(0.0, min(100.0, charterState.guestHappiness + event.impact.guestHappinessDelta))
                    charterState.staffStress = max(0.0, min(100.0, charterState.staffStress + event.impact.staffStressDelta))
                    
                    // Add event to history
                    gameState.charterEvents.append(event)
                    
                    // Show notification for significant events
                    if abs(event.impact.guestHappinessDelta) > 5 || abs(event.impact.staffStressDelta) > 5 {
                        let icon = event.impact.guestHappinessDelta > 0 ? "✨" : "⚠️"
                        showToast("\(icon) \(event.message)")
                    }
                }
            }
        }
        
        // Update crew stress levels
        updateCrewStress(vessel: vessel, charterState: charterState)
        
        gameState.activeCharterState = charterState
        
        // Check if charter is complete
        if progress >= 1.0 {
            completeActiveCharter(charter)
        }
    }
    
    func updateCharterMetrics(_ charterState: inout ActiveCharterState, charter: Charter, vessel: Vessel, hoursDelta: Double) {
        // Calculate crew performance (improved starting scores)
        let crewPerformance = calculateCrewPerformance(vessel: vessel)
        
        // Calculate provisions impact from packages (new system)
        var provisionsSatisfactionBonus = 0.0
        if let selectedPackages = gameState.vesselProvisionPackages[vessel.id] {
            provisionsSatisfactionBonus = selectedPackages.totalSatisfactionBonus
        } else if let provisions = gameState.vesselProvisions[vessel.id] {
            // Legacy system fallback
            let crewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
            let requiredUnits = ProvisionsCalculator.calculateRequiredUnits(
                for: charter,
                guests: charter.guests,
                crewCount: crewCount
            )
            let plan = ProvisionsPlan(
                charterId: charter.id,
                quality: provisions.quality,
                requiredUnits: requiredUnits,
                loadedUnits: provisions.loadedUnits,
                unitCost: provisions.unitCost,
                totalCost: Double(provisions.loadedUnits) * provisions.unitCost
            )
            let provisionsScore = ProvisionsCalculator.calculateCuisineScore(
                plan: plan,
                expectation: charter.cuisineExpectation
            )
            // Convert legacy score to bonus (rough approximation)
            provisionsSatisfactionBonus = (provisionsScore - 3.0) * 5.0
        }
        
        // Check for luxury employees (chef, bartender, masseuse)
        let hasChef = vessel.assignedCrew.contains { crewId in
            gameState.hiredCrew.first(where: { $0.id == crewId })?.role == .chef
        }
        let hasBartender = vessel.assignedCrew.contains { crewId in
            gameState.hiredCrew.first(where: { $0.id == crewId })?.role == .bartender
        }
        let hasMasseuse = vessel.assignedCrew.contains { crewId in
            gameState.hiredCrew.first(where: { $0.id == crewId })?.role == .masseuse
        }
        let hasLuxuryEmployees = hasChef && hasBartender && hasMasseuse
        
        // Scale changes by hoursDelta to convert from per-update to per-hour rates
        // All changes are now per-hour, scaled by hoursDelta
        
        // Update guest happiness
        var happinessChangePerHour: Double = 0.0
        
        // Service quality from crew (improved - starts higher, more positive impact)
        let serviceImpact = (crewPerformance.serviceScore - 3.0) * 2.0 // Per hour: -6 to +4
        happinessChangePerHour += serviceImpact
        
        // Cuisine quality from provisions packages (much more significant)
        let cuisineImpact = provisionsSatisfactionBonus * 0.5 // Convert % bonus to per-hour change
        happinessChangePerHour += cuisineImpact
        
        // Activities impact
        let activitiesImpact = (crewPerformance.activitiesScore - 3.0) * 1.5 // Per hour
        happinessChangePerHour += activitiesImpact
        
        // Weather impact (scaled appropriately)
        let weatherModifier = charterState.weather.guestHappinessModifier
        happinessChangePerHour += (weatherModifier - 1.0) * 3.0 // Per hour: -0.9 (storm) to 0 (sunny)
        
        // Staff stress impact (scaled)
        let stressPenalty = (charterState.staffStress / 100.0) * 2.0 // Per hour: up to -2.0
        happinessChangePerHour -= stressPenalty
        
        // Vessel condition impact
        let conditionImpact = ((vessel.condition / 100.0) - 0.8) * 1.0 // Per hour
        happinessChangePerHour += conditionImpact
        
        // Positive baseline drift when things are going well
        if charterState.guestHappiness > 60 && charterState.staffStress < 50 {
            happinessChangePerHour += 0.5 // Small positive drift
        }
        
        // Premium provisions + luxury employees guarantee high satisfaction
        if provisionsSatisfactionBonus >= 50.0 && hasLuxuryEmployees {
            // Ensure we're trending toward 90+
            if charterState.guestHappiness < 90 {
                happinessChangePerHour += 5.0 // Strong push toward 90+
            } else {
                // Maintain high satisfaction
                happinessChangePerHour += 1.0
            }
        }
        
        // Apply change scaled by time delta
        let happinessChange = happinessChangePerHour * hoursDelta
        charterState.guestHappiness = max(0.0, min(100.0, charterState.guestHappiness + happinessChange))
        
        // Update staff stress
        var stressChangePerHour: Double = 0.0
        
        // Base stress accumulation (much slower - per hour instead of per update)
        stressChangePerHour += 1.0 // 1 point per hour (was 0.05 per update = 30/hour)
        
        // Weather impact (scaled)
        stressChangePerHour += (charterState.weather.staffStressModifier - 1.0) * 3.0 // Per hour
        
        // Crew experience helps manage stress
        let avgExperience = calculateAverageCrewExperience(vessel: vessel)
        stressChangePerHour -= (avgExperience / 10.0) * 2.0 // Per hour: up to -2.0 with high experience
        
        // Understaffing increases stress
        let crewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
        if crewCount < vessel.crewRec {
            let shortageRatio = Double(vessel.crewRec - crewCount) / Double(vessel.crewRec)
            stressChangePerHour += shortageRatio * 5.0 // Per hour: up to +5.0
        }
        
        // Overstaffing reduces stress
        if crewCount > vessel.crewRec {
            stressChangePerHour -= 1.0 // Per hour
        }
        
        // Stress recovery when conditions are good
        if charterState.staffStress > 30 && charterState.weather == .sunny && crewCount >= vessel.crewRec {
            stressChangePerHour -= 2.0 // Recovery per hour
        }
        
        // Apply change scaled by time delta
        let stressChange = stressChangePerHour * hoursDelta
        charterState.staffStress = max(0.0, min(100.0, charterState.staffStress + stressChange))
    }
    
    func calculateCrewPerformance(vessel: Vessel) -> (serviceScore: Double, cuisineScore: Double, activitiesScore: Double) {
        var serviceScore = 3.5 // Start higher (was 2.5)
        var cuisineScore = 3.0 // Start higher (was 1.5)
        var activitiesScore = 3.0 // Start higher (was 2.0)
        
        // Captain contribution
        if let captainId = vessel.assignedCaptain,
           let captain = gameState.hiredCaptains.first(where: { $0.id == captainId }) {
            // Captain affects service and safety
            serviceScore += captain.personality * 0.4 // Personality scales 1-5, adds up to 2.0
            serviceScore += captain.efficiency * 0.2 // Efficiency adds up to 1.0
        }
        
        // Calculate from crew members
        var hasChef = false
        var hasSteward = false
        var stewardCount = 0
        
        for crewId in vessel.assignedCrew {
            if let crew = gameState.hiredCrew.first(where: { $0.id == crewId }) {
                // Effectiveness based on skill and stress
                let stressPenalty = crew.currentStress / 100.0
                let effectiveness = crew.skillRating * (1.0 - stressPenalty * 0.5) // Stress reduces effectiveness
                
                // Role-specific contributions
                switch crew.role {
                case .chef:
                    hasChef = true
                    cuisineScore += effectiveness * 1.2 // Chef is crucial for cuisine
                case .chiefSteward, .steward:
                    hasSteward = true
                    stewardCount += 1
                    serviceScore += effectiveness * 0.4 // Stewards crucial for service
                case .bartender:
                    serviceScore += effectiveness * 0.3
                    activitiesScore += effectiveness * 0.2
                case .masseuse:
                    activitiesScore += effectiveness * 0.5
                    serviceScore += effectiveness * 0.2
                case .firstMate, .deckhand, .deckStew:
                    // Deck crew helps with activities and general service
                    activitiesScore += effectiveness * 0.2
                    serviceScore += effectiveness * 0.15
                case .engineer:
                    // Engineer helps with safety and vessel reliability
                    // (No direct impact on service/cuisine/activities scores)
                    break
                case .surfInstructor:
                    // Surf instructor helps with activities
                    activitiesScore += effectiveness * 0.4
                    serviceScore += effectiveness * 0.1
                }
            }
        }
        
        // Penalties for missing key roles
        if !hasChef {
            cuisineScore -= 0.8 // Significant penalty for no chef
        }
        
        if !hasSteward {
            serviceScore -= 0.5 // Penalty for no stewards
        } else if stewardCount < 2 && vessel.lengthFeet > 80 {
            // Large vessels need multiple stewards
            serviceScore -= 0.3
        }
        
        // Ensure scores are within bounds
        return (
            serviceScore: max(1.0, min(5.0, serviceScore)),
            cuisineScore: max(1.0, min(5.0, cuisineScore)),
            activitiesScore: max(1.0, min(5.0, activitiesScore))
        )
    }
    
    func calculateAverageCrewExperience(vessel: Vessel) -> Double {
        var totalExperience = 0.0
        var count = 0
        
        for crewId in vessel.assignedCrew {
            if let crew = gameState.hiredCrew.first(where: { $0.id == crewId }) {
                totalExperience += Double(crew.experienceYears)
                count += 1
            }
        }
        
        if let captainId = vessel.assignedCaptain,
           let captain = gameState.hiredCaptains.first(where: { $0.id == captainId }) {
            totalExperience += captain.experience * 10 // Convert to years estimate
            count += 1
        }
        
        return count > 0 ? totalExperience / Double(count) : 0.0
    }
    
    func toggleCharterPause() {
        guard var charterState = gameState.activeCharterState else { return }
        charterState.isPaused.toggle()
        gameState.activeCharterState = charterState
        
        if charterState.isPaused {
            charterTimer?.invalidate()
        } else {
            startCharterSimulation()
        }
    }
    
    func setCharterSpeed(multiplier: Double) {
        guard var charterState = gameState.activeCharterState else { return }
        charterState.speedMultiplier = multiplier
        gameState.activeCharterState = charterState
    }
    
    func updateCrewStress(vessel: Vessel, charterState: ActiveCharterState) {
        // Update individual crew stress based on overall stress and their experience
        for crewId in vessel.assignedCrew {
            if let crewIndex = gameState.hiredCrew.firstIndex(where: { $0.id == crewId }) {
                // Base stress from charter state
                var crewStress = charterState.staffStress
                
                // Experience helps manage stress
                let experienceModifier = Double(gameState.hiredCrew[crewIndex].experienceYears) / 10.0
                crewStress -= experienceModifier * 5.0
                
                // Weather impact
                crewStress += (charterState.weather.staffStressModifier - 1.0) * 10.0
                
                gameState.hiredCrew[crewIndex].currentStress = max(0.0, min(100.0, crewStress))
            }
        }
    }
    
    func completeActiveCharter(_ charter: Charter) {
        charterTimer?.invalidate()
        
        // Calculate final outcomes based on guest happiness and staff stress
        var finalHappiness = 70.0
        var finalStress = 20.0
        
        if let charterState = gameState.activeCharterState {
            finalHappiness = charterState.guestHappiness
            finalStress = charterState.staffStress
        }
        
        // Complete charter with adjusted values based on happiness/stress FIRST
        completeCharter(charter, finalHappiness: finalHappiness, finalStress: finalStress)
        
        // THEN clear charter events and state
        gameState.charterEvents = []
        gameState.activeCharterState = nil
        showingActiveCharter = false
    }
    
    func skipToCharterEnd() {
        guard let charterState = gameState.activeCharterState,
              let charter = gameState.activeCharters.first(where: { $0.id == charterState.charterId }) else {
            return
        }
        
        // Stop the timer
        charterTimer?.invalidate()
        
        // Set elapsed time to full duration to complete the charter
        var updatedState = charterState
        updatedState.elapsedTime = charter.durationDays * 86400 // Full duration
        
        // Final update to metrics before completion
        if let vessel = gameState.ownedVessels.first(where: { $0.id == charterState.vesselId }) {
            let hoursDelta = updatedState.elapsedTime / 3600.0
            updateCharterMetrics(&updatedState, charter: charter, vessel: vessel, hoursDelta: hoursDelta)
        }
        
        gameState.activeCharterState = updatedState
        
        // Complete the charter
        completeActiveCharter(charter)
    }
    
    func loadProvisions(vesselId: String, plan: ProvisionsPlan) -> Bool {
        guard gameState.cash >= plan.totalCost else {
            showToast("Insufficient funds for provisions. Need $\(Int(plan.totalCost))")
            return false
        }
        
        gameState.cash -= plan.totalCost
        gameState.vesselProvisions[vesselId] = Provisions(
            quality: plan.quality,
            loadedUnits: plan.loadedUnits,
            unitCost: plan.unitCost
        )
        
        showToast("Loaded \(plan.loadedUnits) units of \(plan.quality.rawValue) provisions")
        return true
    }
    
    func loadProvisionPackages(vesselId: String, packages: SelectedProvisions) -> Bool {
        guard gameState.cash >= packages.totalCost else {
            showToast("Insufficient funds for provisions. Need $\(Int(packages.totalCost))")
            return false
        }
        
        gameState.cash -= packages.totalCost
        gameState.vesselProvisionPackages[vesselId] = packages
        
        let packageNames = packages.packages.compactMap { ProvisionPackageCatalog.package(withId: $0)?.name }
        showToast("Loaded \(packageNames.count) provision packages")
        return true
    }

    func completeCharter(_ charter: Charter, finalHappiness: Double = 70.0, finalStress: Double = 20.0) {
        guard let charterIndex = gameState.activeCharters.firstIndex(where: { $0.id == charter.id }),
              let vesselId = charter.assignedVessel,
              let vesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }) else {
            return
        }

        let vessel = gameState.ownedVessels[vesselIndex]

        // Calculate satisfaction using final happiness and stress from charter
        let satisfaction = calculateSatisfaction(
            charter: charter,
            vessel: vessel,
            finalHappiness: finalHappiness,
            finalStress: finalStress
        )
        
        // Calculate tip rate based on satisfaction
        var tipRate = calculateTipRate(charter: charter, satisfaction: satisfaction)
        
        // Additional happiness modifiers (on top of satisfaction-based tips)
        if finalHappiness < 30 {
            tipRate = 0.0 // No tip if very unhappy
        } else if finalHappiness < 50 {
            tipRate *= 0.3 // Severely reduced tip
        } else if finalHappiness < 60 {
            tipRate *= 0.6 // Reduced tip
        } else if finalHappiness >= 85 {
            tipRate *= 1.2 // Bonus tip for excellent service
        } else if finalHappiness >= 95 {
            tipRate *= 1.5 // Large bonus for outstanding service
        }
        
        // Staff stress penalty (even if happiness is okay, high stress can reduce tips)
        if finalStress > 70 {
            tipRate *= 0.8 // High stress reduces tips
        } else if finalStress > 50 {
            tipRate *= 0.9 // Moderate stress slightly reduces tips
        }
        
        // Very low happiness = client refuses full payment
        var paymentMultiplier = 1.0
        if finalHappiness < 30 {
            paymentMultiplier = 0.7 // Client refuses 30% of payment
        } else if finalHappiness < 50 {
            paymentMultiplier = 0.85 // Client refuses 15% of payment
        }
        
        let tipAmount = charter.basePay * tipRate
        let totalPay = (charter.basePay * paymentMultiplier) + tipAmount

        // Calculate costs
        let daysRounded = Int(ceil(charter.durationDays))
        let opexCost = vessel.dailyOpex * Double(daysRounded)

        // Crew costs (captain + all crew)
        var crewCost = 0.0
        
        // Captain cost
        if let captainId = vessel.assignedCaptain,
           let captain = gameState.hiredCaptains.first(where: { $0.id == captainId }) {
            crewCost += captain.dayRate * Double(daysRounded)
        }
        
        // Crew member costs
        for crewId in vessel.assignedCrew {
            if let crew = gameState.hiredCrew.first(where: { $0.id == crewId }) {
                crewCost += crew.dayRate * Double(daysRounded)
            }
        }

        let repairCost = vessel.purchasePrice * 0.001 // 0.1% of vessel value
        let cleaningCost = Double(vessel.lengthFeet) * 10.0
        
        // Calculate spoilage loss from provisions (legacy system only - packages don't spoil)
        var spoilageLoss = 0.0
        if let provisions = gameState.vesselProvisions[vesselId] {
            let crewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
            let requiredUnits = ProvisionsCalculator.calculateRequiredUnits(
                for: charter,
                guests: charter.guests,
                crewCount: crewCount
            )
            let remainingUnits = max(0, provisions.loadedUnits - requiredUnits)
            spoilageLoss = Double(remainingUnits) * provisions.unitCost
            
            // Wipe provisions after charter (as per handoff doc requirement)
            gameState.vesselProvisions.removeValue(forKey: vesselId)
        }
        
        // Wipe provision packages after charter (they're consumed)
        gameState.vesselProvisionPackages.removeValue(forKey: vesselId)

        let totalCosts = opexCost + crewCost + repairCost + cleaningCost + spoilageLoss
        let netProfit = totalPay - totalCosts

        // Create trip summary
        let summary = TripSummary(
            charter: charter,
            basePay: charter.basePay,
            tipAmount: tipAmount,
            tipRate: tipRate,
            totalPay: totalPay,
            opexCost: opexCost + crewCost,
            repairCost: repairCost,
            cleaningCost: cleaningCost,
            spoilageLoss: spoilageLoss,
            netProfit: netProfit,
            satisfaction: satisfaction
        )

        // Update game state
        gameState.cash += netProfit
        gameState.reputation += 1

        // Move charter to completed
        var completedCharter = gameState.activeCharters[charterIndex]
        completedCharter.status = .completed
        completedCharter.completionDate = gameState.currentDate
        gameState.completedCharters.append(completedCharter)
        gameState.activeCharters.remove(at: charterIndex)

        // Update vessel
        gameState.ownedVessels[vesselIndex].status = .moored
        gameState.ownedVessels[vesselIndex].currentLocation = charter.destination
        gameState.ownedVessels[vesselIndex].condition -= 2.0

        // Show summary
        currentTripSummary = summary
        showingTripSummary = true
    }

    // MARK: - Calculations
    private func calculateSatisfaction(charter: Charter, vessel: Vessel, finalHappiness: Double? = nil, finalStress: Double? = nil) -> SatisfactionScores {
        // Get crew performance scores
        let crewPerformance = calculateCrewPerformance(vessel: vessel)
        
        // Start with crew performance as base
        var service = crewPerformance.serviceScore
        var cuisine = crewPerformance.cuisineScore
        var activities = crewPerformance.activitiesScore
        var comfort = 3.5 // Base comfort score
        
        // Captain contribution (additional to crew)
        if let captainId = vessel.assignedCaptain,
           let captain = gameState.hiredCaptains.first(where: { $0.id == captainId }) {
            // Service already includes captain, but add personality bonus
            service += (captain.personality - 3.0) * 0.2 // Adjust around midpoint
        }
        
        // Cuisine: Use provision packages (new system) or legacy provisions
        if let selectedPackages = gameState.vesselProvisionPackages[vessel.id] {
            // New package system - calculate cuisine from food packages
            let foodPackages = selectedPackages.packages.compactMap { id -> ProvisionPackage? in
                guard let pkg = ProvisionPackageCatalog.package(withId: id) else { return nil }
                return pkg.category == .food ? pkg : nil
            }
            
            if !foodPackages.isEmpty {
                // Food packages significantly boost cuisine
                let foodBonus = foodPackages.reduce(0.0) { $0 + $1.satisfactionBonus }
                // Convert bonus % to score (e.g., 25% bonus = +1.25 to score)
                let cuisineBoost = foodBonus / 20.0 // Scale: 20% = +1.0 score
                cuisine = min(5.0, cuisine + cuisineBoost)
            } else {
                // No food packages = penalty
                cuisine = max(1.0, cuisine - 1.0)
            }
        } else if let provisions = gameState.vesselProvisions[vessel.id] {
            // Legacy system fallback
            let crewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
            let plan = ProvisionsPlan(
                charterId: charter.id,
                quality: provisions.quality,
                requiredUnits: ProvisionsCalculator.calculateRequiredUnits(
                    for: charter,
                    guests: charter.guests,
                    crewCount: crewCount
                ),
                loadedUnits: provisions.loadedUnits,
                unitCost: provisions.unitCost,
                totalCost: Double(provisions.loadedUnits) * provisions.unitCost
            )
            let provisionsScore = ProvisionsCalculator.calculateCuisineScore(
                plan: plan,
                expectation: charter.cuisineExpectation
            )
            // Blend crew cuisine score with provisions score
            cuisine = (cuisine * 0.6) + (provisionsScore * 0.4)
        } else {
            // No provisions = severe penalty
            cuisine = max(1.0, cuisine - 1.5)
        }
        
        // Activities: Boost from entertainment packages
        if let selectedPackages = gameState.vesselProvisionPackages[vessel.id] {
            let entertainmentPackages = selectedPackages.packages.compactMap { id -> ProvisionPackage? in
                guard let pkg = ProvisionPackageCatalog.package(withId: id) else { return nil }
                return pkg.category == .entertainment ? pkg : nil
            }
            
            if !entertainmentPackages.isEmpty {
                let entertainmentBonus = entertainmentPackages.reduce(0.0) { $0 + $1.satisfactionBonus }
                let activitiesBoost = entertainmentBonus / 20.0 // Scale: 20% = +1.0 score
                activities = min(5.0, activities + activitiesBoost)
            }
        }
        
        // Comfort: Boost from comfort/security packages
        if let selectedPackages = gameState.vesselProvisionPackages[vessel.id] {
            let comfortPackages = selectedPackages.packages.compactMap { id -> ProvisionPackage? in
                guard let pkg = ProvisionPackageCatalog.package(withId: id) else { return nil }
                return pkg.category == .comfortSecurity ? pkg : nil
            }
            
            if !comfortPackages.isEmpty {
                let comfortBonus = comfortPackages.reduce(0.0) { $0 + $1.satisfactionBonus }
                let comfortBoost = comfortBonus / 20.0 // Scale: 20% = +1.0 score
                comfort = min(5.0, comfort + comfortBoost)
            }
        }
        
        // Safety: Captain experience + vessel condition + crew experience
        var safety = 3.0
        if let captainId = vessel.assignedCaptain,
           let captain = gameState.hiredCaptains.first(where: { $0.id == captainId }) {
            safety = captain.experience * 0.7 + (vessel.condition / 100.0) * 1.5
        } else {
            safety = (vessel.condition / 100.0) * 2.0 // No captain = lower safety
        }
        
        // Add crew experience bonus
        let avgExperience = calculateAverageCrewExperience(vessel: vessel)
        safety += (avgExperience / 10.0) * 0.3
        safety = min(5.0, max(1.0, safety))
        
        // Comfort: Vessel quality + weather (if available from charter state)
        comfort += (vessel.condition / 100.0) * 0.8 // Condition affects comfort
        if vessel.lengthFeet > 100 {
            comfort += 0.3 // Larger vessels = more comfortable
        } else if vessel.lengthFeet < 50 {
            comfort -= 0.2 // Smaller vessels = less comfortable
        }
        
        // Activities: Support items + vessel capabilities + crew
        if !vessel.supportItems.isEmpty {
            activities += 0.5
        }
        if charter.category == .adventure && vessel.isExplorer {
            activities += 0.5
        }
        
        // Apply final happiness and stress modifiers if provided
        if let happiness = finalHappiness, let stress = finalStress {
            // Happiness affects all scores
            let happinessMultiplier = happiness / 100.0
            
            // Stress penalty affects service and safety
            let stressPenalty = (stress / 100.0) * 0.4 // Up to 40% penalty
            
            service = max(1.0, min(5.0, service * happinessMultiplier - stressPenalty))
            cuisine = max(1.0, min(5.0, cuisine * happinessMultiplier))
            safety = max(1.0, min(5.0, safety - stressPenalty))
            comfort = max(1.0, min(5.0, comfort * happinessMultiplier))
            activities = max(1.0, min(5.0, activities * happinessMultiplier))
        }
        
        // Ensure all scores are within bounds
        return SatisfactionScores(
            service: max(1.0, min(5.0, service)),
            cuisine: max(1.0, min(5.0, cuisine)),
            safety: max(1.0, min(5.0, safety)),
            comfort: max(1.0, min(5.0, comfort)),
            activities: max(1.0, min(5.0, activities))
        )
    }

    private func calculateTipRate(charter: Charter, satisfaction: SatisfactionScores) -> Double {
        let overall = satisfaction.overall

        switch charter.category {
        case .transport:
            return 0.0
        case .fishing:
            return overall >= 4.0 ? 0.20 : 0.10
        case .luxury, .adventure:
            if overall >= 4.5 {
                return 0.30
            } else if overall >= 4.0 {
                return 0.20
            } else {
                return 0.10
            }
        case .vip, .ultraVIP:
            if overall >= 4.5 {
                return 0.35
            } else if overall >= 4.0 {
                return 0.25
            } else {
                return 0.15
            }
        }
    }

    // MARK: - Time Management
    private var lastCharterRefreshDate: Date?
    
    func advanceTime(days: Int = 1) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: gameState.currentDate) else {
            return
        }
        gameState.currentDate = newDate

        // Check if any charters should complete
        checkCharterCompletion()
        
        // Refresh charter market periodically (every 3 days)
        let calendar = Calendar.current
        if let lastRefresh = lastCharterRefreshDate {
            let daysSinceRefresh = calendar.dateComponents([.day], from: lastRefresh, to: gameState.currentDate).day ?? 0
            if daysSinceRefresh >= 3 {
                refreshCharters()
                lastCharterRefreshDate = gameState.currentDate
            }
        } else {
            // First time, set refresh date
            lastCharterRefreshDate = gameState.currentDate
        }
    }

    private func checkCharterCompletion() {
        // Create a copy to iterate over (since completeCharter modifies the array)
        let activeChartersCopy = gameState.activeCharters

        for charter in activeChartersCopy {
            if let startDate = charter.startDate {
                // Use hours for accurate fractional day calculation
                let timeInterval = gameState.currentDate.timeIntervalSince(startDate)
                let daysPassed = timeInterval / 86400.0 // 86400 seconds in a day

                if daysPassed >= charter.durationDays {
                    completeCharter(charter)
                    showToast("✅ Charter completed! +$\(Int(charter.basePay))")
                }
            }
        }
    }

    // MARK: - Utilities
    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.toastMessage = nil
        }
    }
}
