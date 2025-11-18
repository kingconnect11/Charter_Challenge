import Foundation
import CoreLocation

// MARK: - Port Model
struct Port: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double
    let description: String

    // Port infrastructure
    let marinaCapacity: Int // Total berths
    let currentBerths: Int // Available berths
    let maxDraft: Double? // Maximum draft in feet (nil = no restriction)
    let fuelPrice: Double? // Price per gallon (nil = no fuel available)
    let hasWaterMaker: Bool // Can produce fresh water
    let wasteCapacity: Int? // Waste disposal capacity (nil = unlimited)
    let notes: String? // Local quirks and notes

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    var hasAvailableBerth: Bool {
        currentBerths > 0
    }
    
    func canAccommodateDraft(_ draft: Double) -> Bool {
        guard let maxDraft = maxDraft else { return true }
        return draft <= maxDraft
    }
}

// MARK: - Port Registry
struct PortRegistry {
    static var all: [Port] = [
        Port(
            id: "marina_del_rey",
            name: "Marina Del Rey",
            region: "Southern California",
            latitude: 33.9806,
            longitude: -118.4517,
            description: "One of the largest man-made small-craft harbors in North America, featuring over 5,000 boats and a vibrant coastal community.",
            marinaCapacity: 5000,
            currentBerths: 4500,
            maxDraft: nil as Double?,
            fuelPrice: 4.25,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Prime location with excellent facilities. Can get crowded during summer months."
        ),
        Port(
            id: "san_diego",
            name: "San Diego",
            region: "Southern California",
            latitude: 32.7157,
            longitude: -117.1611,
            description: "America's finest city offers world-class sailing conditions, multiple marinas, and a thriving charter industry with year-round sunshine.",
            marinaCapacity: 3000,
            currentBerths: 2800,
            maxDraft: nil as Double?,
            fuelPrice: 4.15,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Multiple marina options. Fuel prices competitive."
        ),
        Port(
            id: "catalina",
            name: "Catalina Island",
            region: "Southern California",
            latitude: 33.3427,
            longitude: -118.3287,
            description: "Two Harbors and Avalon provide protected anchorages with crystal clear waters, stunning marine life, and that classic California island escape.",
            marinaCapacity: 200,
            currentBerths: 150,
            maxDraft: 12.0,
            fuelPrice: 5.50,
            hasWaterMaker: false,
            wasteCapacity: 50,
            notes: "Limited berths, book ahead. Fuel is expensive. Fresh water available but limited."
        ),
        Port(
            id: "seattle",
            name: "Seattle",
            region: "Pacific Northwest",
            latitude: 47.6062,
            longitude: -122.3321,
            description: "Gateway to the Pacific Northwest with excellent facilities and access to the San Juan Islands.",
            marinaCapacity: 2000,
            currentBerths: 1800,
            maxDraft: nil as Double?,
            fuelPrice: 4.50,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Excellent facilities. Peak season is summer."
        ),
        Port(
            id: "friday_harbor",
            name: "Friday Harbor",
            region: "Pacific Northwest",
            latitude: 48.5343,
            longitude: -123.0171,
            description: "Charming island port in the San Juans, popular with charter guests seeking quiet anchorages.",
            marinaCapacity: 300,
            currentBerths: 250,
            maxDraft: 15.0,
            fuelPrice: 5.00,
            hasWaterMaker: false,
            wasteCapacity: 100,
            notes: "Small port, limited facilities. Beautiful location."
        ),
        Port(
            id: "vancouver",
            name: "Vancouver",
            region: "Pacific Northwest",
            latitude: 49.2827,
            longitude: -123.1207,
            description: "Major Canadian port with world-class facilities and access to British Columbia's stunning coastline.",
            marinaCapacity: 1500,
            currentBerths: 1400,
            maxDraft: nil as Double?,
            fuelPrice: 4.75,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "International port, customs clearance required."
        ),
        Port(
            id: "astoria",
            name: "Astoria",
            region: "Pacific Northwest",
            latitude: 46.1881,
            longitude: -123.8290,
            description: "Historic port at the mouth of the Columbia River, gateway to the Pacific.",
            marinaCapacity: 400,
            currentBerths: 350,
            maxDraft: 20.0,
            fuelPrice: 4.30,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Bar crossing can be challenging in rough weather."
        ),
        Port(
            id: "san_francisco",
            name: "San Francisco",
            region: "Northern California",
            latitude: 37.7749,
            longitude: -122.4194,
            description: "Iconic bay city with multiple marinas and access to the Pacific.",
            marinaCapacity: 2500,
            currentBerths: 2200,
            maxDraft: nil as Double?,
            fuelPrice: 4.60,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Foggy in summer. Strong currents in the bay."
        ),
        Port(
            id: "sausalito",
            name: "Sausalito",
            region: "Northern California",
            latitude: 37.8591,
            longitude: -122.4853,
            description: "Picturesque town across the Golden Gate Bridge, popular with charter guests.",
            marinaCapacity: 800,
            currentBerths: 700,
            maxDraft: nil as Double?,
            fuelPrice: 4.70,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Charming location, popular destination."
        ),
        Port(
            id: "santa_cruz",
            name: "Santa Cruz",
            region: "Northern California",
            latitude: 36.9741,
            longitude: -122.0308,
            description: "Surfing capital with a relaxed vibe and good facilities.",
            marinaCapacity: 600,
            currentBerths: 550,
            maxDraft: 12.0,
            fuelPrice: 4.40,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Surfing culture, laid-back atmosphere."
        ),
        Port(
            id: "santa_barbara",
            name: "Santa Barbara",
            region: "Southern California",
            latitude: 34.4208,
            longitude: -119.6982,
            description: "The American Riviera, known for Mediterranean climate and upscale charters.",
            marinaCapacity: 1200,
            currentBerths: 1100,
            maxDraft: nil as Double?,
            fuelPrice: 4.55,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Upscale destination, premium charters common."
        ),
        Port(
            id: "cabo_san_lucas",
            name: "Cabo San Lucas",
            region: "Baja California",
            latitude: 22.8905,
            longitude: -109.9167,
            description: "Mexican resort destination at the tip of Baja, popular for luxury charters.",
            marinaCapacity: 500,
            currentBerths: 450,
            maxDraft: nil as Double?,
            fuelPrice: 3.80,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "International destination, customs required. Peak season is winter."
        ),
        Port(
            id: "miami",
            name: "Miami",
            region: "Florida",
            latitude: 25.7617,
            longitude: -80.1918,
            description: "Gateway to the Caribbean and Bahamas, major superyacht hub.",
            marinaCapacity: 3000,
            currentBerths: 2800,
            maxDraft: nil as Double?,
            fuelPrice: 4.20,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Superyacht capital. Peak season is winter. Can be very busy."
        ),
        Port(
            id: "charleston",
            name: "Charleston",
            region: "South Carolina",
            latitude: 32.7765,
            longitude: -79.9311,
            description: "Historic southern port with excellent facilities and charm.",
            marinaCapacity: 800,
            currentBerths: 750,
            maxDraft: 18.0,
            fuelPrice: 4.10,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Historic charm, good facilities."
        ),
        Port(
            id: "new_york",
            name: "New York",
            region: "Northeast",
            latitude: 40.7128,
            longitude: -74.0060,
            description: "Major metropolitan port with world-class facilities.",
            marinaCapacity: 2000,
            currentBerths: 1800,
            maxDraft: nil as Double?,
            fuelPrice: 4.80,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Expensive but excellent facilities. Very busy."
        ),
        Port(
            id: "st_thomas",
            name: "St. Thomas",
            region: "Caribbean",
            latitude: 18.3358,
            longitude: -64.8963,
            description: "US Virgin Islands port, popular Caribbean charter destination.",
            marinaCapacity: 400,
            currentBerths: 350,
            maxDraft: 15.0,
            fuelPrice: 5.20,
            hasWaterMaker: false,
            wasteCapacity: 80,
            notes: "Caribbean paradise. Limited facilities, expensive fuel. Peak season is winter."
        ),
        Port(
            id: "st_barths",
            name: "St. Barths",
            region: "Caribbean",
            latitude: 17.9000,
            longitude: -62.8333,
            description: "Ultra-luxury Caribbean destination, playground for superyachts.",
            marinaCapacity: 100,
            currentBerths: 80,
            maxDraft: 12.0,
            fuelPrice: 6.50,
            hasWaterMaker: false,
            wasteCapacity: 30,
            notes: "Ultra-exclusive. Very limited berths, very expensive. Book months in advance for peak season."
        ),
        Port(
            id: "san_juan_pr",
            name: "San Juan, PR",
            region: "Caribbean",
            latitude: 18.4655,
            longitude: -66.1057,
            description: "Puerto Rican capital with good facilities and Caribbean access.",
            marinaCapacity: 600,
            currentBerths: 550,
            maxDraft: nil as Double?,
            fuelPrice: 4.90,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "US territory, no customs needed. Good facilities."
        ),
        Port(
            id: "honolulu",
            name: "Honolulu",
            region: "Hawaii",
            latitude: 21.3099,
            longitude: -157.8581,
            description: "Pacific paradise with excellent facilities and year-round charter opportunities.",
            marinaCapacity: 1500,
            currentBerths: 1400,
            maxDraft: nil as Double?,
            fuelPrice: 5.40,
            hasWaterMaker: true,
            wasteCapacity: nil as Int?,
            notes: "Remote location, expensive fuel. Year-round destination."
        )
    ]

    static func port(withId id: String) -> Port? {
        all.first { $0.id == id }
    }

    static func port(withName name: String) -> Port? {
        all.first { $0.name == name }
    }

    // Calculate distance between two ports in nautical miles
    static func distance(from: Port, to: Port) -> Double {
        let distanceMeters = from.location.distance(from: to.location)
        let nauticalMiles = distanceMeters / 1852.0 // 1 NM = 1852 meters
        return nauticalMiles
    }

    // Calculate travel time in days based on vessel speed
    static func travelTime(from: Port, to: Port, vesselSpeedKnots: Double) -> Double {
        let distanceNM = distance(from: from, to: to)
        let hours = distanceNM / vesselSpeedKnots
        return hours / 24.0 // Convert to days
    }
}
