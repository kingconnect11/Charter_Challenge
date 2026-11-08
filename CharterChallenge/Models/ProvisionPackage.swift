import Foundation

// MARK: - Provision Package Category
enum ProvisionCategory: String, Codable, CaseIterable, Sendable {
    case alcoholBeverages = "Alcohol & Beverages"
    case food = "Food"
    case entertainment = "Entertainment"
    case comfortSecurity = "Comfort & Security"
    
    var icon: String {
        switch self {
        case .alcoholBeverages: return "wineglass.fill"
        case .food: return "fork.knife"
        case .entertainment: return "music.note"
        case .comfortSecurity: return "shield.fill"
        }
    }
}

// MARK: - Provision Package
struct ProvisionPackage: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let category: ProvisionCategory
    let name: String
    let priceRating: Int // 1-5
    let satisfactionBonus: Double // Percentage bonus (e.g., 20.0 = +20%)
    let riskChance: Double? // Optional: chance of risk (0.0-1.0), e.g., 0.1 = 10%
    let riskImpact: Double? // Optional: satisfaction impact if risk occurs (can be negative)
    let specialCondition: String? // Optional: special condition text (e.g., "1/10 chance +50% if incident prevented")
    
    var priceMultiplier: Double {
        Double(priceRating) / 5.0 // 1/5 = 0.2x, 5/5 = 1.0x
    }
    
    var baseCost: Double {
        // Base cost calculation - adjust based on price rating
        switch priceRating {
        case 1: return 500.0
        case 2: return 1500.0
        case 3: return 3000.0
        case 4: return 6000.0
        case 5: return 12000.0
        default: return 1000.0
        }
    }
}

// MARK: - Provision Package Catalog
struct ProvisionPackageCatalog {
    static let allPackages: [ProvisionPackage] = [
        // Alcohol & Beverages
        ProvisionPackage(
            id: "champagne_tower",
            category: .alcoholBeverages,
            name: "Champagne Tower",
            priceRating: 5,
            satisfactionBonus: 20.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        ProvisionPackage(
            id: "rare_scotch",
            category: .alcoholBeverages,
            name: "Rare Scotch Tasting",
            priceRating: 5,
            satisfactionBonus: 12.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        ProvisionPackage(
            id: "beer_nuts",
            category: .alcoholBeverages,
            name: "Beer & Bar Nuts",
            priceRating: 1,
            satisfactionBonus: 2.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        
        // Food
        ProvisionPackage(
            id: "michelin_tasting",
            category: .food,
            name: "Michelin Star 12-Course Tasting Menu",
            priceRating: 5,
            satisfactionBonus: 25.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        ProvisionPackage(
            id: "sea_tasting",
            category: .food,
            name: "Flavors of the Sea Tasting Menu",
            priceRating: 4,
            satisfactionBonus: 10.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        ProvisionPackage(
            id: "surf_turf",
            category: .food,
            name: "Surf and Turf",
            priceRating: 2,
            satisfactionBonus: 5.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        ProvisionPackage(
            id: "burgers",
            category: .food,
            name: "Burgers",
            priceRating: 1,
            satisfactionBonus: 2.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        
        // Entertainment
        ProvisionPackage(
            id: "live_dj",
            category: .entertainment,
            name: "Live DJ with Bottle Service & Dancers",
            priceRating: 5,
            satisfactionBonus: 15.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        ProvisionPackage(
            id: "intoxicate_concierge",
            category: .entertainment,
            name: "Intoxicate Concierge",
            priceRating: 4,
            satisfactionBonus: 30.0,
            riskChance: 0.1, // 1/10 chance
            riskImpact: -10.0, // -10% satisfaction if risk occurs
            specialCondition: "1/10 chance satisfaction decreases 10%"
        ),
        ProvisionPackage(
            id: "submarine",
            category: .entertainment,
            name: "Submarine Excursion",
            priceRating: 4,
            satisfactionBonus: 20.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        
        // Comfort & Security
        ProvisionPackage(
            id: "custom_linen",
            category: .comfortSecurity,
            name: "Custom Linen Set and Bathrobes",
            priceRating: 2,
            satisfactionBonus: 8.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        ProvisionPackage(
            id: "loropiana",
            category: .comfortSecurity,
            name: "LoroPiana Blankets and Scarves",
            priceRating: 5,
            satisfactionBonus: 15.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        ProvisionPackage(
            id: "shopping_trip",
            category: .comfortSecurity,
            name: "Shopping Trip On Land",
            priceRating: 2,
            satisfactionBonus: 5.0,
            riskChance: nil,
            riskImpact: nil,
            specialCondition: nil
        ),
        ProvisionPackage(
            id: "security_guard",
            category: .comfortSecurity,
            name: "Extra Security Guard",
            priceRating: 3,
            satisfactionBonus: 5.0,
            riskChance: 0.1, // 1/10 chance
            riskImpact: 50.0, // +50% satisfaction if incident prevented
            specialCondition: "1/10 chance +50% satisfaction if incident prevented"
        )
    ]
    
    static func packages(for category: ProvisionCategory) -> [ProvisionPackage] {
        allPackages.filter { $0.category == category }
    }
    
    static func package(withId id: String) -> ProvisionPackage? {
        allPackages.first { $0.id == id }
    }
}

// MARK: - Selected Provisions
struct SelectedProvisions: Codable, Sendable {
    var packages: [String] // Package IDs
    var totalCost: Double
    var totalSatisfactionBonus: Double
    
    init(packages: [String] = []) {
        self.packages = packages
        self.totalCost = 0.0
        self.totalSatisfactionBonus = 0.0
        self.calculateTotals()
    }
    
    mutating func calculateTotals() {
        totalCost = packages.compactMap { ProvisionPackageCatalog.package(withId: $0)?.baseCost }.reduce(0, +)
        totalSatisfactionBonus = packages.compactMap { ProvisionPackageCatalog.package(withId: $0)?.satisfactionBonus }.reduce(0, +)
    }
    
    mutating func addPackage(_ packageId: String) {
        if !packages.contains(packageId) {
            packages.append(packageId)
            calculateTotals()
        }
    }
    
    mutating func removePackage(_ packageId: String) {
        packages.removeAll { $0 == packageId }
        calculateTotals()
    }
    
    func hasPackage(_ packageId: String) -> Bool {
        packages.contains(packageId)
    }
}



