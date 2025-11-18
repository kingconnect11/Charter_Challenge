import Foundation
import SwiftUI
import Combine

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
    
    // Active charter simulation timer
    private var charterTimer: Timer?

    init() {
        self.gameState = GameState()
        loadCatalogs()
        generateStarterCharters()
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
        
        let distance = PortRegistry.distance(from: originPort, to: destPort)
        
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
            speedMultiplier: 1.0
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
        
        // Calculate progress
        let totalDuration = charter.durationDays * 86400 // Convert days to seconds
        let progress = min(1.0, charterState.elapsedTime / totalDuration)
        
        // Update position (interpolate between origin and destination)
        let lat = originPort.latitude + (destPort.latitude - originPort.latitude) * progress
        let lon = originPort.longitude + (destPort.longitude - originPort.longitude) * progress
        
        let distance = PortRegistry.distance(from: originPort, to: destPort)
        charterState.currentPosition = RoutePosition(
            progress: progress,
            currentLatitude: lat,
            currentLongitude: lon,
            distanceRemaining: distance * (1.0 - progress)
        )
        
        // Update guest happiness and staff stress
        updateCharterMetrics(&charterState, charter: charter, vessel: vessel)
        
        // Update weather (random changes)
        if Int.random(in: 0...100) < 5 { // 5% chance per update
            charterState.weather = [.sunny, .cloudy, .rain, .storm].randomElement() ?? .sunny
            charterState.windSpeed = Double.random(in: 5...25)
        }
        
        // Generate charter events
        let crewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
        if let event = CharterEventGenerator.generateEvent(
            charterState: charterState,
            vessel: vessel,
            crewCount: crewCount,
            crewStress: charterState.staffStress
        ) {
            // Apply event impact
            charterState.guestHappiness = max(0.0, min(100.0, charterState.guestHappiness + event.impact.guestHappinessDelta))
            charterState.staffStress = max(0.0, min(100.0, charterState.staffStress + event.impact.staffStressDelta))
            
            // Add event to history
            gameState.charterEvents.append(event)
            
            // Show notification for significant events
            if abs(event.impact.guestHappinessDelta) > 5 || abs(event.impact.staffStressDelta) > 5 {
                showToast("⚠️ \(event.message)")
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
    
    func updateCharterMetrics(_ charterState: inout ActiveCharterState, charter: Charter, vessel: Vessel) {
        // Calculate crew performance
        let crewPerformance = calculateCrewPerformance(vessel: vessel)
        
        // Update guest happiness
        var happinessChange: Double = 0.0
        
        // Base service quality
        happinessChange += crewPerformance.serviceScore * 0.1
        
        // Weather impact
        happinessChange += (charterState.weather.guestHappinessModifier - 1.0) * 5.0
        
        // Staff stress impact (high stress = lower happiness)
        happinessChange -= (charterState.staffStress / 100.0) * 0.2
        
        charterState.guestHappiness = max(0.0, min(100.0, charterState.guestHappiness + happinessChange))
        
        // Update staff stress
        var stressChange: Double = 0.0
        
        // Base stress accumulation
        stressChange += 0.1 // Natural accumulation
        
        // Weather impact
        stressChange += (charterState.weather.staffStressModifier - 1.0) * 2.0
        
        // Crew experience helps manage stress
        let avgExperience = calculateAverageCrewExperience(vessel: vessel)
        stressChange -= (avgExperience / 10.0) * 0.05
        
        // Understaffing increases stress
        let crewCount = vessel.assignedCrew.count + (vessel.assignedCaptain != nil ? 1 : 0)
        if crewCount < vessel.crewRec {
            stressChange += 0.2
        }
        
        charterState.staffStress = max(0.0, min(100.0, charterState.staffStress + stressChange))
    }
    
    func calculateCrewPerformance(vessel: Vessel) -> (serviceScore: Double, cuisineScore: Double, activitiesScore: Double) {
        var serviceScore = 3.0
        var cuisineScore = 2.0
        var activitiesScore = 3.0
        
        // Calculate from crew
        for crewId in vessel.assignedCrew {
            if let crew = gameState.hiredCrew.first(where: { $0.id == crewId }) {
                let effectiveness = crew.skillRating * (1.0 - crew.currentStress / 100.0)
                
                if crew.role.affectsService {
                    serviceScore += effectiveness * 0.3
                }
                if crew.role.affectsCuisine {
                    cuisineScore += effectiveness * 0.5
                }
                if crew.role.affectsActivities {
                    activitiesScore += effectiveness * 0.4
                }
            }
        }
        
        return (
            serviceScore: min(5.0, serviceScore),
            cuisineScore: min(5.0, cuisineScore),
            activitiesScore: min(5.0, activitiesScore)
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
        
        // Clear charter events
        gameState.charterEvents = []
        
        gameState.activeCharterState = nil
        showingActiveCharter = false
        
        // Complete charter with adjusted values based on happiness/stress
        completeCharter(charter, finalHappiness: finalHappiness, finalStress: finalStress)
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

    func completeCharter(_ charter: Charter, finalHappiness: Double = 70.0, finalStress: Double = 20.0) {
        guard let charterIndex = gameState.activeCharters.firstIndex(where: { $0.id == charter.id }),
              let vesselId = charter.assignedVessel,
              let vesselIndex = gameState.ownedVessels.firstIndex(where: { $0.id == vesselId }) else {
            return
        }

        let vessel = gameState.ownedVessels[vesselIndex]

        // Calculate satisfaction and tips
        var satisfaction = calculateSatisfaction(charter: charter, vessel: vessel)
        
        // Adjust satisfaction based on guest happiness and staff stress
        let happinessMultiplier = finalHappiness / 100.0
        let stressPenalty = finalStress / 100.0 * 0.3 // Up to 30% penalty
        
        satisfaction = SatisfactionScores(
            service: max(1.0, min(5.0, satisfaction.service * happinessMultiplier - stressPenalty)),
            cuisine: max(1.0, min(5.0, satisfaction.cuisine * happinessMultiplier)),
            safety: max(1.0, min(5.0, satisfaction.safety - stressPenalty)),
            comfort: max(1.0, min(5.0, satisfaction.comfort * happinessMultiplier)),
            activities: max(1.0, min(5.0, satisfaction.activities * happinessMultiplier))
        )
        
        // Adjust tip rate based on happiness
        var tipRate = calculateTipRate(charter: charter, satisfaction: satisfaction)
        
        // Happiness affects tip percentage
        if finalHappiness < 40 {
            tipRate = 0.0 // No tip if very unhappy
        } else if finalHappiness < 60 {
            tipRate *= 0.5 // Reduced tip
        } else if finalHappiness >= 90 {
            tipRate *= 1.5 // Bonus tip for excellent service
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
        
        // Calculate spoilage loss from provisions
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
    private func calculateSatisfaction(charter: Charter, vessel: Vessel) -> SatisfactionScores {
        // Service score based on captain personality and crew
        var service = 3.0
        if let captainId = vessel.assignedCaptain,
           let captain = gameState.hiredCaptains.first(where: { $0.id == captainId }) {
            service = captain.personality * 0.8 + 1.0 // Scale personality to 1-5
        }
        
        // Cuisine score based on provisions
        var cuisine = 2.0
        if let provisions = gameState.vesselProvisions[vessel.id] {
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
            cuisine = ProvisionsCalculator.calculateCuisineScore(
                plan: plan,
                expectation: charter.cuisineExpectation
            )
        } else {
            // No provisions = poor cuisine
            cuisine = 1.0
        }
        
        // Safety score based on captain experience and vessel condition
        var safety = 3.0
        if let captainId = vessel.assignedCaptain,
           let captain = gameState.hiredCaptains.first(where: { $0.id == captainId }) {
            safety = captain.experience * 0.9 + (vessel.condition / 100.0) * 0.5
        }
        safety = min(5.0, safety)
        
        // Comfort based on vessel and sea state (simplified for now)
        let comfort = 4.0
        
        // Activities based on support items and vessel capabilities
        var activities = 3.0
        if !vessel.supportItems.isEmpty {
            activities = 4.0
        }
        if charter.category == .adventure && vessel.isExplorer {
            activities += 0.5
        }
        activities = min(5.0, activities)

        return SatisfactionScores(
            service: service,
            cuisine: cuisine,
            safety: safety,
            comfort: comfort,
            activities: activities
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
