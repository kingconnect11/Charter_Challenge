import Foundation

// MARK: - Vessel Model
struct Vessel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let category: VesselCategory
    let lengthFeet: Int
    let speedKnots: Double
    let rangeNM: Int
    let costPerNM: Double
    let dailyOpex: Double
    let guestCapacity: Int
    let earningMultiplier: Double
    let purchasePrice: Double
    let isExplorer: Bool

    // Crew requirements
    let crewMin: Int
    let crewRec: Int
    let crewMax: Int

    // Storage
    let pantryUnits: Int
    let coldStorageUnits: Int
    let galleyGrade: Int // 1-5

    // Instance state (for owned vessels)
    var status: VesselStatus = .moored
    var currentLocation: String = "Sausalito"
    var assignedCaptain: String? = nil
    var assignedCrew: [String] = []
    var condition: Double = 100.0 // 0-100
    var supportItems: [String] = []
    
    // Fuel state (for owned vessels)
    var fuelCapacity: Double = 0.0 // gallons (calculated from range)
    var currentFuel: Double = 0.0 // gallons
    var selectedSpeed: Double = 0.0 // knots (player's speed choice)

    enum CodingKeys: String, CodingKey {
        case id, name, category, lengthFeet, speedKnots, rangeNM
        case costPerNM, dailyOpex, guestCapacity, earningMultiplier
        case purchasePrice, isExplorer, crewMin, crewRec, crewMax
        case pantryUnits, coldStorageUnits, galleyGrade
        // Runtime properties (status, currentLocation, etc.) are not in JSON
        // They use default values when decoding
    }
    
    // Computed properties for fuel calculations
    var performance: VesselPerformance {
        VesselPerformanceFactory.performanceFor(vessel: self)
    }
    
    var fuelPercentage: Double {
        guard fuelCapacity > 0 else { return 0.0 }
        return (currentFuel / fuelCapacity) * 100.0
    }
    
    var requiresRefueling: Bool {
        fuelPercentage < 20.0 // Reserve threshold
    }
    
    // Initialize fuel capacity based on range
    mutating func initializeFuel() {
        let performance = VesselPerformanceFactory.performanceFor(vessel: self)
        // Estimate fuel capacity needed for max range at optimal speed
        let optimalFuelRate = performance.fuelBurnRate(at: performance.optimalSpeed)
        let hoursAtOptimalSpeed = Double(rangeNM) / performance.optimalSpeed
        fuelCapacity = optimalFuelRate * hoursAtOptimalSpeed * 1.2 // 20% reserve
        currentFuel = fuelCapacity // Start with full tank
        selectedSpeed = performance.optimalSpeed // Default to optimal speed
    }
}

enum VesselCategory: String, Codable, Sendable {
    case tender = "Tender"
    case sportsman = "Sportsman"
    case yacht = "Yacht"
    case superYacht = "Super Yacht"
    case gigaYacht = "Giga Yacht"
}

enum VesselStatus: String, Codable, Sendable {
    case moored = "Moored"
    case sailing = "Sailing"
    case shipping = "Shipping"
    case charter = "Charter"
    case maintenance = "Maintenance"
}
