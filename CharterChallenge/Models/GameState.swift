import Foundation

// MARK: - Game State
struct GameState: Codable, Sendable {
    var currentDate: Date
    var cash: Double
    var reputation: Int
    var loans: [Loan]
    var ownedVessels: [Vessel]
    var hiredCaptains: [Captain]
    var hiredCrew: [CrewMember]
    var availableCharters: [Charter]
    var activeCharters: [Charter]
    var completedCharters: [Charter]

    // Provisions tracking
    var vesselProvisions: [String: Provisions] // vesselId: provisions
    
    // Active charter simulation state
    var activeCharterState: ActiveCharterState?
    var charterEvents: [CharterEvent] = [] // Events during active charter

    init() {
        self.currentDate = DateComponents(calendar: .current, year: 2025, month: 1, day: 1).date!
        self.cash = 3000000.0 // $3M for prototype - enough to buy Zeelander 55 + hire captain
        self.reputation = 0
        self.loans = []
        self.ownedVessels = []
        self.hiredCaptains = []
        self.hiredCrew = []
        self.availableCharters = []
        self.activeCharters = []
        self.completedCharters = []
        self.vesselProvisions = [:]
        self.activeCharterState = nil
        self.charterEvents = []
    }
}

// MARK: - Loan
struct Loan: Identifiable, Codable, Sendable {
    let id: String
    let principal: Double
    let interestRate: Double // Monthly simple interest
    let dateIssued: Date
    var remainingBalance: Double
}

// MARK: - Provision Quality
enum ProvisionQuality: String, Codable, Sendable {
    case basic = "Basic"
    case standard = "Standard"
    case premium = "Premium"

    var multiplier: Double {
        switch self {
        case .basic: return 0.8
        case .standard: return 1.0
        case .premium: return 1.3
        }
    }
}

// MARK: - Provisions
struct Provisions: Codable, Hashable, Sendable {
    var quality: ProvisionQuality
    var loadedUnits: Int
    var unitCost: Double
}

// MARK: - Trip Summary
struct TripSummary: Sendable {
    let charter: Charter
    let basePay: Double
    let tipAmount: Double
    let tipRate: Double
    let totalPay: Double
    let opexCost: Double
    let repairCost: Double
    let cleaningCost: Double
    let spoilageLoss: Double
    let netProfit: Double
    let satisfaction: SatisfactionScores
}

struct SatisfactionScores: Sendable {
    let service: Double
    let cuisine: Double
    let safety: Double
    let comfort: Double
    let activities: Double

    var overall: Double {
        (service + cuisine + safety + comfort + activities) / 5.0
    }
}
