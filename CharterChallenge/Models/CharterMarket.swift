import Foundation

// MARK: - Charter Market Model
struct CharterMarket: Codable, Sendable {
    var regionDemand: [String: RegionDemand] // region: demand model
    var lastGeneratedDate: Date
    var generatedCharters: [Charter]
}

// MARK: - Region Demand
struct RegionDemand: Codable, Sendable {
    let baseDemand: Double // 0.0 - 1.0
    let seasonalMultiplier: [Int: Double] // month (1-12): multiplier
    let holidaySpikes: [Date: Double] // date: multiplier
    let weatherSensitivity: Double // 0.0 - 1.0, how much weather affects demand
    
    func getDemandMultiplier(for date: Date) -> Double {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        var multiplier = seasonalMultiplier[month] ?? 1.0
        
        // Apply holiday spikes
        for (holidayDate, spike) in holidaySpikes {
            let daysDiff = abs(calendar.dateComponents([.day], from: date, to: holidayDate).day ?? 0)
            if daysDiff <= 7 { // Within a week of holiday
                multiplier += spike * (1.0 - Double(daysDiff) / 7.0)
            }
        }
        
        return multiplier
    }
}

// MARK: - Charter Market Generator
class CharterMarketGenerator {
    static let shared = CharterMarketGenerator()
    
    private init() {}
    
    // Generate charters based on date, location, reputation, and market conditions
    func generateCharters(
        for date: Date,
        at ports: [Port],
        reputation: Int,
        weatherCondition: WeatherCondition = .sunny
    ) -> [Charter] {
        var charters: [Charter] = []
        
        // Always include starter charters for low reputation
        if reputation == 0 {
            charters.append(contentsOf: generateStarterCharters())
        }
        
        // Generate region-based charters
        for port in ports {
            let regionCharters = generateChartersForRegion(
                port: port,
                date: date,
                reputation: reputation,
                weatherCondition: weatherCondition
            )
            charters.append(contentsOf: regionCharters)
        }
        
        // Add special event charters
        charters.append(contentsOf: generateEventCharters(date: date, reputation: reputation))
        
        return charters
    }
    
    private func generateChartersForRegion(
        port: Port,
        date: Date,
        reputation: Int,
        weatherCondition: WeatherCondition
    ) -> [Charter] {
        var charters: [Charter] = []
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        
        // Base demand varies by region and season
        let baseDemand = getBaseDemandForRegion(port.region, month: month)
        let weatherModifier = getWeatherModifier(weatherCondition)
        let adjustedDemand = baseDemand * weatherModifier
        
        // Generate charters based on demand
        let charterCount = Int(adjustedDemand * 3) // 0-3 charters per region
        
        for _ in 0..<charterCount {
            if let charter = generateRandomCharter(
                origin: port.name,
                date: date,
                reputation: reputation,
                region: port.region
            ) {
                charters.append(charter)
            }
        }
        
        return charters
    }
    
    private func generateRandomCharter(
        origin: String,
        date: Date,
        reputation: Int,
        region: String
    ) -> Charter? {
        // Select destination (could be same port for local charters)
        let destinations = PortRegistry.all.map { $0.name }
        guard let destination = destinations.randomElement() else { return nil }
        
        // Select category based on reputation
        let category = selectCategoryForReputation(reputation)
        
        // Generate charter details
        let guests = Int.random(in: 4...12)
        let durationDays = Double.random(in: 0.25...7.0) // 6 hours to 7 days
        let basePay = calculateBasePay(
            category: category,
            guests: guests,
            durationDays: durationDays,
            region: region
        )
        
        return Charter(
            id: "charter_\(UUID().uuidString.prefix(8))",
            title: generateCharterTitle(category: category, origin: origin, destination: destination),
            category: category,
            origin: origin,
            destination: destination,
            guests: guests,
            durationDays: durationDays,
            basePay: basePay,
            reputationRequired: getReputationRequirement(category: category),
            startDate: nil,
            requiresExplorer: category == .adventure,
            minimumStews: category == .luxury || category == .vip || category == .ultraVIP ? 2 : 0,
            minimumCrewRating: category == .luxury || category == .vip || category == .ultraVIP ? 4.0 : 0.0,
            serviceExpectation: getServiceExpectation(category: category),
            cuisineExpectation: getCuisineExpectation(category: category),
            activitiesExpectation: getActivitiesExpectation(category: category)
        )
    }
    
    private func generateStarterCharters() -> [Charter] {
        // Prom Night - 6 hour charter (Marina Del Rey loop)
        let promNight = Charter(
            id: "charter_prom_\(UUID().uuidString.prefix(8))",
            title: "Prom Night Marina Cruise",
            category: .fishing,
            origin: "Marina Del Rey",
            destination: "Marina Del Rey",
            guests: 8,
            durationDays: 0.25, // 6 hours
            basePay: 8000,
            reputationRequired: 0,
            startDate: nil,
            requiresExplorer: false,
            minimumStews: 0,
            minimumCrewRating: 0,
            serviceExpectation: 3.0,
            cuisineExpectation: 2.5,
            activitiesExpectation: 3.5
        )
        
        // Transport charter
        let transport = Charter(
            id: "charter_transport_\(UUID().uuidString.prefix(8))",
            title: "Equipment Transport",
            category: .transport,
            origin: "Marina Del Rey",
            destination: "San Diego",
            guests: 0,
            durationDays: 1.0,
            basePay: 5000,
            reputationRequired: 0,
            startDate: nil,
            requiresExplorer: false,
            minimumStews: 0,
            minimumCrewRating: 0,
            serviceExpectation: 1.0,
            cuisineExpectation: 1.0,
            activitiesExpectation: 1.0
        )
        
        return [promNight, transport]
    }
    
    private func generateEventCharters(date: Date, reputation: Int) -> [Charter] {
        var charters: [Charter] = []
        let calendar = Calendar.current
        
        // Check for special events based on date
        // Example: Cannes Film Festival (May)
        if calendar.component(.month, from: date) == 5 && reputation >= 3 {
            let cannesCharter = Charter(
                id: "charter_cannes_\(UUID().uuidString.prefix(8))",
                title: "Cannes Film Festival VIP Charter",
                category: .ultraVIP,
                origin: "Monaco",
                destination: "Cannes",
                guests: 12,
                durationDays: 7.0,
                basePay: 150000,
                reputationRequired: 3,
                startDate: nil,
                requiresExplorer: false,
                minimumStews: 4,
                minimumCrewRating: 4.5,
                serviceExpectation: 5.0,
                cuisineExpectation: 5.0,
                activitiesExpectation: 5.0
            )
            charters.append(cannesCharter)
        }
        
        return charters
    }
    
    // MARK: - Helper Methods
    
    private func selectCategoryForReputation(_ reputation: Int) -> CharterCategory {
        switch reputation {
        case 0:
            return Bool.random() ? .transport : .fishing
        case 1...2:
            return [.fishing, .adventure].randomElement() ?? .fishing
        case 3...4:
            return [.adventure, .luxury].randomElement() ?? .luxury
        case 5...6:
            return [.luxury, .vip].randomElement() ?? .vip
        default:
            return [.vip, .ultraVIP].randomElement() ?? .ultraVIP
        }
    }
    
    private func calculateBasePay(
        category: CharterCategory,
        guests: Int,
        durationDays: Double,
        region: String
    ) -> Double {
        let baseRate: Double
        switch category {
        case .transport:
            baseRate = 5000
        case .fishing:
            baseRate = 8000
        case .adventure:
            baseRate = 15000
        case .luxury:
            baseRate = 30000
        case .vip:
            baseRate = 60000
        case .ultraVIP:
            baseRate = 120000
        }
        
        // Scale by guests and duration
        let guestMultiplier = Double(guests) / 8.0
        let durationMultiplier = durationDays
        let regionMultiplier = getRegionMultiplier(region)
        
        return baseRate * guestMultiplier * durationMultiplier * regionMultiplier
    }
    
    private func getRegionMultiplier(_ region: String) -> Double {
        // Premium regions pay more
        switch region {
        case "Mediterranean", "Caribbean":
            return 1.3
        case "Southern California":
            return 1.1
        default:
            return 1.0
        }
    }
    
    private func getReputationRequirement(category: CharterCategory) -> Int {
        switch category {
        case .transport, .fishing:
            return 0
        case .adventure:
            return 1
        case .luxury:
            return 2
        case .vip:
            return 3
        case .ultraVIP:
            return 5
        }
    }
    
    private func getServiceExpectation(category: CharterCategory) -> Double {
        switch category {
        case .transport: return 1.0
        case .fishing: return 3.0
        case .adventure: return 3.5
        case .luxury: return 4.0
        case .vip: return 4.5
        case .ultraVIP: return 5.0
        }
    }
    
    private func getCuisineExpectation(category: CharterCategory) -> Double {
        switch category {
        case .transport: return 1.0
        case .fishing: return 2.5
        case .adventure: return 3.5
        case .luxury: return 4.0
        case .vip: return 4.5
        case .ultraVIP: return 5.0
        }
    }
    
    private func getActivitiesExpectation(category: CharterCategory) -> Double {
        switch category {
        case .transport: return 1.0
        case .fishing: return 3.5
        case .adventure: return 4.5
        case .luxury: return 3.5
        case .vip: return 4.0
        case .ultraVIP: return 5.0
        }
    }
    
    private func getBaseDemandForRegion(_ region: String, month: Int) -> Double {
        // Seasonal demand patterns
        let base: Double
        switch region {
        case "Southern California":
            base = 0.7 // High year-round
        case "Caribbean":
            base = month >= 11 || month <= 3 ? 0.9 : 0.5 // Peak in winter
        case "Mediterranean":
            base = month >= 5 && month <= 9 ? 0.9 : 0.4 // Peak in summer
        default:
            base = 0.5
        }
        return base
    }
    
    private func getWeatherModifier(_ condition: WeatherCondition) -> Double {
        switch condition {
        case .sunny:
            return 1.1 // Slightly increases demand
        case .cloudy:
            return 1.0
        case .rain:
            return 0.85 // Reduces luxury demand
        case .storm:
            return 0.7 // Significantly reduces demand
        }
    }
    
    private func generateCharterTitle(category: CharterCategory, origin: String, destination: String) -> String {
        let titles: [String]
        switch category {
        case .transport:
            titles = ["Equipment Transport", "Cargo Delivery", "Repositioning Charter"]
        case .fishing:
            titles = ["Fishing Expedition", "Sport Fishing Charter", "Deep Sea Fishing"]
        case .adventure:
            titles = ["Adventure Cruise", "Exploration Charter", "Expedition Voyage"]
        case .luxury:
            titles = ["Luxury Yacht Charter", "Premium Cruise", "Exclusive Charter"]
        case .vip:
            titles = ["VIP Charter", "Executive Retreat", "Premium Experience"]
        case .ultraVIP:
            titles = ["Ultra VIP Charter", "Exclusive Luxury Experience", "Premium VIP Voyage"]
        }
        
        let baseTitle = titles.randomElement() ?? "Charter"
        if origin != destination {
            return "\(baseTitle): \(origin) to \(destination)"
        } else {
            return "\(baseTitle): \(origin)"
        }
    }
}

// Note: WeatherCondition is defined in ActiveCharterState.swift

