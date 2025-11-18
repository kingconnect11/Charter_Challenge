import Foundation

// MARK: - Provisions Plan
struct ProvisionsPlan: Codable, Sendable {
    let charterId: String
    let quality: ProvisionQuality
    let requiredUnits: Int
    let loadedUnits: Int
    let unitCost: Double
    let totalCost: Double
    
    var remainingUnits: Int {
        max(0, loadedUnits - requiredUnits)
    }
    
    var spoilageLoss: Double {
        Double(remainingUnits) * unitCost
    }
}

// MARK: - Provisions Calculator
struct ProvisionsCalculator {
    // Calculate required provisions for a charter
    static func calculateRequiredUnits(
        for charter: Charter,
        guests: Int,
        crewCount: Int
    ) -> Int {
        let totalPeople = guests + crewCount
        let days = Int(ceil(charter.durationDays))
        
        // Base requirement: people * days * base multiplier
        var multiplier: Double = 1.0
        
        // Adjust multiplier based on charter category
        switch charter.category {
        case .transport:
            multiplier = 0.5 // Minimal provisions
        case .fishing:
            multiplier = 1.0 // Standard
        case .adventure:
            multiplier = 1.2 // More provisions for activities
        case .luxury:
            multiplier = 1.5 // Premium dining
        case .vip:
            multiplier = 2.0 // Extensive provisions
        case .ultraVIP:
            multiplier = 2.5 // Ultra-premium
        }
        
        return Int(Double(totalPeople * days) * multiplier)
    }
    
    // Calculate unit cost based on quality
    static func unitCost(for quality: ProvisionQuality) -> Double {
        switch quality {
        case .basic:
            return 15.0 // $15 per unit
        case .standard:
            return 25.0 // $25 per unit
        case .premium:
            return 40.0 // $40 per unit
        }
    }
    
    // Create a provisions plan
    static func createPlan(
        for charter: Charter,
        guests: Int,
        crewCount: Int,
        quality: ProvisionQuality,
        loadedUnits: Int? = nil // If nil, calculate optimal amount
    ) -> ProvisionsPlan {
        let requiredUnits = calculateRequiredUnits(
            for: charter,
            guests: guests,
            crewCount: crewCount
        )
        
        let unitsToLoad = loadedUnits ?? requiredUnits
        let costPerUnit = unitCost(for: quality)
        let totalCost = Double(unitsToLoad) * costPerUnit
        
        return ProvisionsPlan(
            charterId: charter.id,
            quality: quality,
            requiredUnits: requiredUnits,
            loadedUnits: unitsToLoad,
            unitCost: costPerUnit,
            totalCost: totalCost
        )
    }
    
    // Calculate cuisine score based on provisions
    static func calculateCuisineScore(
        plan: ProvisionsPlan,
        expectation: Double
    ) -> Double {
        let adequacyRatio = Double(plan.loadedUnits) / Double(plan.requiredUnits)
        let qualityMultiplier = plan.quality.multiplier
        
        // Base score from adequacy
        var score = min(5.0, expectation * adequacyRatio)
        
        // Adjust for quality
        score = score * qualityMultiplier
        
        // Cap at expectation + 0.5 for excellent provisioning
        if adequacyRatio >= 1.0 && qualityMultiplier >= 1.0 {
            score = min(5.0, expectation + 0.5)
        }
        
        // Penalty for under-provisioning
        if adequacyRatio < 0.8 {
            score = score * 0.7 // Significant penalty
        } else if adequacyRatio < 0.9 {
            score = score * 0.85 // Moderate penalty
        }
        
        return max(1.0, min(5.0, score))
    }
}

