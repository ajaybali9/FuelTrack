import Foundation

enum FuelType: String, CaseIterable, Codable, Identifiable, Sendable {
    case petrolE10
    case petrolE5
    case diesel
    case dieselPremium
    case lpg
    case electric
    case hybrid
    case other

    /// Legacy stored value from earlier builds.
    case petrol

    var id: String { rawValue }

    /// Cases shown in pickers (hides legacy `petrol`).
    static var selectableCases: [FuelType] {
        [.petrolE10, .petrolE5, .diesel, .dieselPremium, .lpg, .electric, .hybrid, .other]
    }

    static func fromStored(_ raw: String) -> FuelType {
        if raw == "petrol" { return .petrolE10 }
        return FuelType(rawValue: raw) ?? .other
    }

    var displayName: String {
        switch self {
        case .petrol, .petrolE10: "Petrol E10"
        case .petrolE5: "Super Unleaded E5"
        case .diesel: "Diesel"
        case .dieselPremium: "Premium Diesel"
        case .lpg: "LPG"
        case .electric: "Electric"
        case .hybrid: "Hybrid"
        case .other: "Other"
        }
    }

    var shortName: String {
        switch self {
        case .petrol, .petrolE10: "E10"
        case .petrolE5: "E5"
        case .diesel: "Diesel"
        case .dieselPremium: "Prem. Diesel"
        case .lpg: "LPG"
        case .electric: "EV"
        case .hybrid: "Hybrid"
        case .other: "Other"
        }
    }

    /// UK Fuel Finder / Cheapest Fuel API fuel code, when available.
    var nearbyAPIFuelCode: String? {
        switch self {
        case .petrol, .petrolE10: "E10"
        case .petrolE5: "E5"
        case .diesel, .dieselPremium: "B7"
        default: nil
        }
    }

    var supportsNearbyPrices: Bool { nearbyAPIFuelCode != nil }
}
