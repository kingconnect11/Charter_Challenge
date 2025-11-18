import Foundation

// MARK: - Charter Model
struct Charter: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let category: CharterCategory
    let origin: String
    let destination: String
    let guests: Int
    let durationDays: Double // 0.25 for 6-hour
    let basePay: Double
    let reputationRequired: Int
    var startDate: Date?

    // Requirements
    let requiresExplorer: Bool
    let minimumStews: Int
    let minimumCrewRating: Double

    // Expectations
    let serviceExpectation: Double
    let cuisineExpectation: Double
    let activitiesExpectation: Double

    var status: CharterStatus = .available
    var assignedVessel: String? = nil
    var completionDate: Date? = nil
}

enum CharterCategory: String, Codable, Sendable {
    case transport = "Transport"
    case fishing = "Fishing"
    case adventure = "Adventure"
    case luxury = "Luxury"
    case vip = "VIP"
    case ultraVIP = "Ultra VIP"
}

enum CharterStatus: String, Codable, Sendable {
    case available = "Available"
    case inProgress = "In Progress"
    case completed = "Completed"
}
