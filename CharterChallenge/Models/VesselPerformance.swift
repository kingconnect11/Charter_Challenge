import Foundation

// MARK: - Vessel Performance Model
struct VesselPerformance: Codable, Sendable {
    let minCruiseSpeed: Double // Minimum efficient cruise speed (knots)
    let maxCruiseSpeed: Double // Maximum cruise speed (knots)
    let optimalSpeed: Double // Most fuel-efficient speed (knots)
    let idleFuelBurn: Double // Fuel burn at idle (gallons per hour)
    let hotelLoadFuelBurn: Double // Fuel burn for hotel load (gallons per hour)
    
    // Fuel burn curve coefficients (cubic function: fuel = a*speed^3 + b*speed^2 + c*speed + d)
    let fuelCurveA: Double
    let fuelCurveB: Double
    let fuelCurveC: Double
    let fuelCurveD: Double
    
    // Calculate fuel burn rate at given speed (gallons per hour)
    func fuelBurnRate(at speed: Double) -> Double {
        // Ensure speed is within bounds
        let clampedSpeed = max(minCruiseSpeed, min(maxCruiseSpeed, speed))
        
        // Cubic fuel burn curve
        let fuelRate = fuelCurveA * pow(clampedSpeed, 3) +
                      fuelCurveB * pow(clampedSpeed, 2) +
                      fuelCurveC * clampedSpeed +
                      fuelCurveD
        
        // Add idle/hotel load floor
        return max(idleFuelBurn + hotelLoadFuelBurn, fuelRate)
    }
    
    // Calculate fuel consumption for a voyage
    func calculateFuelConsumption(
        speed: Double,
        distanceNM: Double,
        seaState: SeaState
    ) -> Double {
        let baseSpeed = max(minCruiseSpeed, min(maxCruiseSpeed, speed))
        
        // Apply sea state penalty
        let effectiveSpeed = applySeaStatePenalty(speed: baseSpeed, seaState: seaState)
        let effectiveFuelRate = fuelBurnRate(at: effectiveSpeed)
        
        // Calculate time at sea
        let hoursAtSea = distanceNM / effectiveSpeed
        
        // Total fuel consumption
        return effectiveFuelRate * hoursAtSea
    }
    
    private func applySeaStatePenalty(speed: Double, seaState: SeaState) -> Double {
        switch seaState {
        case .calm:
            return speed // No penalty
        case .moderate:
            return speed * 0.95 // 5% speed reduction
        case .rough:
            return speed * 0.85 // 15% speed reduction
        case .veryRough:
            return speed * 0.70 // 30% speed reduction
        }
    }
}

// MARK: - Sea State
enum SeaState: String, Codable, Sendable {
    case calm = "Calm"
    case moderate = "Moderate"
    case rough = "Rough"
    case veryRough = "Very Rough"
    
    var speedMultiplier: Double {
        switch self {
        case .calm: return 1.0
        case .moderate: return 0.95
        case .rough: return 0.85
        case .veryRough: return 0.70
        }
    }
    
    var fuelMultiplier: Double {
        switch self {
        case .calm: return 1.0
        case .moderate: return 1.05
        case .rough: return 1.15
        case .veryRough: return 1.30
        }
    }
}

// MARK: - Vessel Performance Factory
struct VesselPerformanceFactory {
    // Generate performance profile based on vessel characteristics
    static func performanceFor(vessel: Vessel) -> VesselPerformance {
        let baseSpeed = vessel.speedKnots
        let length = Double(vessel.lengthFeet)
        
        // Performance envelope based on vessel type
        let (minSpeed, maxSpeed, optimalSpeed): (Double, Double, Double)
        
        switch vessel.category {
        case .tender:
            minSpeed = baseSpeed * 0.6
            maxSpeed = baseSpeed * 1.1
            optimalSpeed = baseSpeed * 0.8
        case .sportsman:
            minSpeed = baseSpeed * 0.5
            maxSpeed = baseSpeed * 1.15
            optimalSpeed = baseSpeed * 0.75
        case .yacht:
            minSpeed = baseSpeed * 0.4
            maxSpeed = baseSpeed * 1.2
            optimalSpeed = baseSpeed * 0.7
        case .superYacht, .gigaYacht:
            minSpeed = baseSpeed * 0.5
            maxSpeed = baseSpeed * 1.1
            optimalSpeed = baseSpeed * 0.8
        }
        
        // Idle and hotel load based on vessel size
        let idleFuelBurn = length * 0.5 // gallons per hour
        let hotelLoadFuelBurn = length * 0.3 // gallons per hour
        
        // Fuel curve coefficients (simplified cubic model)
        // For most vessels: fuel increases roughly with speed^3
        let fuelCurveA = 0.01 * (length / 100.0) // Cubic coefficient
        let fuelCurveB = -0.5 * (length / 100.0) // Quadratic coefficient
        let fuelCurveC = 5.0 * (length / 100.0) // Linear coefficient
        let fuelCurveD = idleFuelBurn + hotelLoadFuelBurn // Constant (idle + hotel)
        
        return VesselPerformance(
            minCruiseSpeed: minSpeed,
            maxCruiseSpeed: maxSpeed,
            optimalSpeed: optimalSpeed,
            idleFuelBurn: idleFuelBurn,
            hotelLoadFuelBurn: hotelLoadFuelBurn,
            fuelCurveA: fuelCurveA,
            fuelCurveB: fuelCurveB,
            fuelCurveC: fuelCurveC,
            fuelCurveD: fuelCurveD
        )
    }
}

