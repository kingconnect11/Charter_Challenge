import Foundation

// MARK: - Charter Event
struct CharterEvent: Identifiable, Codable, Sendable {
    let id: String
    let type: EventType
    let message: String
    let timestamp: TimeInterval // Seconds into charter
    let impact: EventImpact
    
    enum EventType: String, Codable, Sendable {
        case incident = "Incident"
        case weatherChange = "Weather Change"
        case guestComplaint = "Guest Complaint"
        case guestPraise = "Guest Praise"
        case crewIssue = "Crew Issue"
        case equipmentFailure = "Equipment Failure"
        case smoothSailing = "Smooth Sailing"
    }
    
    struct EventImpact: Codable, Sendable {
        var guestHappinessDelta: Double = 0.0
        var staffStressDelta: Double = 0.0
        var costDelta: Double = 0.0
    }
}

// MARK: - Charter Event Generator
struct CharterEventGenerator {
    static func generateEvent(
        charterState: ActiveCharterState,
        vessel: Vessel,
        crewCount: Int,
        crewStress: Double
    ) -> CharterEvent? {
        // Reduced overall event frequency - only 30% chance per check (roughly once per 3 hours)
        if Double.random(in: 0...1) > 0.3 {
            return nil
        }
        
        // Higher stress = more likely to have incidents (but less frequent overall)
        let incidentChance = crewStress / 100.0 * 0.3 // Up to 30% chance when stress is high
        
        if Double.random(in: 0...1) < incidentChance {
            return generateIncident(charterState: charterState, crewStress: crewStress)
        }
        
        // Positive events are more common when things are going well
        if charterState.guestHappiness > 70 {
            if Double.random(in: 0...1) < 0.4 { // 40% chance for positive events when happy
                return generatePositiveEvent(charterState: charterState)
            }
        }
        
        // Guest feedback based on happiness
        if Double.random(in: 0...1) < 0.2 { // 20% chance
            if charterState.guestHappiness > 80 {
                return generatePositiveFeedback()
            } else if charterState.guestHappiness < 50 {
                return generateComplaint()
            }
        }
        
        // Weather-related events (less frequent)
        if charterState.weather == .storm && Double.random(in: 0...1) < 0.2 {
            return generateWeatherEvent(charterState: charterState)
        }
        
        // Equipment issues (less frequent)
        if vessel.condition < 70 && Double.random(in: 0...1) < 0.1 {
            return generateEquipmentFailure(vessel: vessel)
        }
        
        // Neutral/interesting events
        if Double.random(in: 0...1) < 0.3 {
            return generateNeutralEvent(charterState: charterState)
        }
        
        return nil
    }
    
    private static func generatePositiveEvent(charterState: ActiveCharterState) -> CharterEvent {
        let events = [
            ("Beautiful sunset over the water", 3.0, -1.0, 0.0),
            ("Dolphin pod spotted alongside", 4.0, -1.0, 0.0),
            ("Perfect weather for water activities", 2.0, -0.5, 0.0),
            ("Guests enjoying the scenery", 2.0, 0.0, 0.0),
            ("Smooth sailing conditions", 3.0, -1.0, 0.0),
            ("Wildlife sighting excites guests", 3.0, 0.0, 0.0)
        ]
        
        let event = events.randomElement()!
        
        return CharterEvent(
            id: UUID().uuidString,
            type: .smoothSailing,
            message: event.0,
            timestamp: charterState.elapsedTime,
            impact: CharterEvent.EventImpact(
                guestHappinessDelta: event.1,
                staffStressDelta: event.2,
                costDelta: event.3
            )
        )
    }
    
    private static func generateNeutralEvent(charterState: ActiveCharterState) -> CharterEvent {
        let events = [
            ("Arrived at scenic anchorage", 1.0, 0.0, 0.0),
            ("Local port visit - guests exploring", 2.0, 0.0, 0.0),
            ("Crew performing routine maintenance", 0.0, 1.0, 0.0),
            ("Weather clearing up", 1.0, -0.5, 0.0),
            ("Guests taking photos of the journey", 1.0, 0.0, 0.0)
        ]
        
        let event = events.randomElement()!
        
        return CharterEvent(
            id: UUID().uuidString,
            type: .smoothSailing,
            message: event.0,
            timestamp: charterState.elapsedTime,
            impact: CharterEvent.EventImpact(
                guestHappinessDelta: event.1,
                staffStressDelta: event.2,
                costDelta: event.3
            )
        )
    }
    
    private static func generateIncident(charterState: ActiveCharterState, crewStress: Double) -> CharterEvent {
        let incidents = [
            ("Minor collision with dock", -5.0, 10.0, 500.0),
            ("Guest injury from slip", -10.0, 15.0, 0.0),
            ("Food service delay", -3.0, 5.0, 0.0),
            ("Equipment malfunction", -2.0, 8.0, 300.0),
            ("Miscommunication with guests", -4.0, 6.0, 0.0)
        ]
        
        let incident = incidents.randomElement()!
        
        return CharterEvent(
            id: UUID().uuidString,
            type: .incident,
            message: incident.0,
            timestamp: charterState.elapsedTime,
            impact: CharterEvent.EventImpact(
                guestHappinessDelta: incident.1,
                staffStressDelta: incident.2,
                costDelta: incident.3
            )
        )
    }
    
    private static func generateComplaint() -> CharterEvent {
        let complaints = [
            ("Guest complains about service speed", -8.0, 5.0, 0.0),
            ("Food quality not meeting expectations", -6.0, 3.0, 0.0),
            ("Room not cleaned properly", -5.0, 4.0, 0.0),
            ("Activities not as advertised", -7.0, 2.0, 0.0)
        ]
        
        let complaint = complaints.randomElement()!
        
        return CharterEvent(
            id: UUID().uuidString,
            type: .guestComplaint,
            message: complaint.0,
            timestamp: Date().timeIntervalSince1970,
            impact: CharterEvent.EventImpact(
                guestHappinessDelta: complaint.1,
                staffStressDelta: complaint.2,
                costDelta: complaint.3
            )
        )
    }
    
    private static func generatePositiveFeedback() -> CharterEvent {
        let praises = [
            ("Guests love the service!", 5.0, -2.0, 0.0),
            ("Excellent meal presentation", 4.0, -1.0, 0.0),
            ("Guests enjoying activities", 6.0, -1.0, 0.0),
            ("Outstanding hospitality", 5.0, -2.0, 0.0)
        ]
        
        let praise = praises.randomElement()!
        
        return CharterEvent(
            id: UUID().uuidString,
            type: .guestPraise,
            message: praise.0,
            timestamp: Date().timeIntervalSince1970,
            impact: CharterEvent.EventImpact(
                guestHappinessDelta: praise.1,
                staffStressDelta: praise.2,
                costDelta: praise.3
            )
        )
    }
    
    private static func generateWeatherEvent(charterState: ActiveCharterState) -> CharterEvent {
        return CharterEvent(
            id: UUID().uuidString,
            type: .weatherChange,
            message: "Heavy weather causing rough seas",
            timestamp: charterState.elapsedTime,
            impact: CharterEvent.EventImpact(
                guestHappinessDelta: -8.0,
                staffStressDelta: 12.0,
                costDelta: 0.0
            )
        )
    }
    
    private static func generateEquipmentFailure(vessel: Vessel) -> CharterEvent {
        return CharterEvent(
            id: UUID().uuidString,
            type: .equipmentFailure,
            message: "Equipment malfunction requires attention",
            timestamp: Date().timeIntervalSince1970,
            impact: CharterEvent.EventImpact(
                guestHappinessDelta: -3.0,
                staffStressDelta: 8.0,
                costDelta: Double(vessel.lengthFeet) * 5.0
            )
        )
    }
    
    private static func generateSmoothSailing() -> CharterEvent {
        return CharterEvent(
            id: UUID().uuidString,
            type: .smoothSailing,
            message: "Perfect conditions and smooth operations",
            timestamp: Date().timeIntervalSince1970,
            impact: CharterEvent.EventImpact(
                guestHappinessDelta: 3.0,
                staffStressDelta: -2.0,
                costDelta: 0.0
            )
        )
    }
}

