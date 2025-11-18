import Foundation

// MARK: - Captain Model
struct Captain: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let quote: String
    let profile: String
    let personality: Double // 0-5
    let efficiency: Double // 0-5
    let experience: Double // 0-5
    let qualifiedLengthFeet: Int
    let dayRate: Double
    let signingBonus: Double
    let recentVessels: [String]

    // Runtime state (not in JSON, use default values)
    var isHired: Bool = false
    var currentVessel: String? = nil
    var isTraining: Bool = false
    var trainingDaysRemaining: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case id, name, quote, profile, personality, efficiency, experience
        case qualifiedLengthFeet, dayRate, signingBonus, recentVessels
        // Runtime properties (isHired, currentVessel, etc.) are not in JSON
    }
}

// MARK: - Crew Member
struct CrewMember: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let role: CrewRole
    let name: String
    let dayRate: Double
    let description: String
    let certifications: [String]
    
    // Performance metrics
    let skillRating: Double // 0-5, affects performance
    let experienceYears: Int // Affects stress handling

    // Effects
    let speedBonus: Double
    let safetyBonus: Double
    let serviceBonus: Double
    let cuisineBonus: Double // For chef
    let activitiesBonus: Double // For masseuse, bartender

    // Runtime state
    var isHired: Bool = false
    var currentVessel: String? = nil
    var currentStress: Double = 0.0 // 0-100%
    
    enum CodingKeys: String, CodingKey {
        case id, role, name, dayRate, description, certifications
        case skillRating, experienceYears
        case speedBonus, safetyBonus, serviceBonus, cuisineBonus, activitiesBonus
        // Runtime properties not in JSON
    }
}

enum CrewRole: String, Codable, CaseIterable, Sendable {
    case chiefSteward = "Chief Steward"
    case steward = "Steward"
    case firstMate = "First Mate"
    case deckhand = "Deckhand"
    case deckStew = "Deck/Stew"
    case masseuse = "Masseuse"
    case bartender = "Bartender"
    case chef = "Chef"
    case engineer = "Engineer"
    case surfInstructor = "Surf Instructor"
    
    var affectsService: Bool {
        switch self {
        case .chiefSteward, .steward, .deckStew, .bartender:
            return true
        default:
            return false
        }
    }
    
    var affectsCuisine: Bool {
        self == .chef
    }
    
    var affectsActivities: Bool {
        self == .masseuse || self == .surfInstructor
    }
    
    var affectsSafety: Bool {
        self == .firstMate || self == .deckhand || self == .engineer
    }
}
