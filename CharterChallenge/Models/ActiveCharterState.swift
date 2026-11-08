import Foundation

// MARK: - Active Charter State
struct ActiveCharterState: Codable, Sendable {
    let charterId: String
    let vesselId: String
    var currentPosition: RoutePosition
    var guestHappiness: Double // 0-100%
    var staffStress: Double // 0-100%
    var weather: WeatherCondition
    var windSpeed: Double // knots
    var startTime: Date
    var elapsedTime: TimeInterval // seconds
    var isPaused: Bool
    var speedMultiplier: Double // 1x, 2x, 5x, 10x, 20x
    var route: MaritimeRoute? // Maritime route with waypoints
    var riskCheckAccumulator: Double = 0.0 // Accumulator for risk checks
    var eventCheckAccumulator: Double = 0.0 // Accumulator for event checks
}

// MARK: - Route Position
struct RoutePosition: Codable, Sendable {
    var progress: Double // 0.0 to 1.0 along the route
    var currentLatitude: Double
    var currentLongitude: Double
    var distanceRemaining: Double // nautical miles
}

// MARK: - Weather Condition
enum WeatherCondition: String, Codable, Sendable {
    case sunny = "Sunny"
    case cloudy = "Cloudy"
    case rain = "Rain"
    case storm = "Storm"
    
    var guestHappinessModifier: Double {
        switch self {
        case .sunny: return 1.0
        case .cloudy: return 0.95
        case .rain: return 0.85
        case .storm: return 0.70
        }
    }
    
    var staffStressModifier: Double {
        switch self {
        case .sunny: return 1.0
        case .cloudy: return 1.05
        case .rain: return 1.15
        case .storm: return 1.30
        }
    }
}

