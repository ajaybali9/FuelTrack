import Foundation

enum OdometerUnit: String, CaseIterable, Codable, Identifiable, Sendable {
    case miles
    case kilometers

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .miles: "mi"
        case .kilometers: "km"
        }
    }

    var displayName: String {
        switch self {
        case .miles: "Miles"
        case .kilometers: "Kilometers"
        }
    }

    /// Convert a distance measured in this unit to kilometers.
    func toKilometers(_ value: Double) -> Double {
        switch self {
        case .miles: value * 1.609344
        case .kilometers: value
        }
    }

    /// Convert kilometers into this unit.
    func fromKilometers(_ kilometers: Double) -> Double {
        switch self {
        case .miles: kilometers / 1.609344
        case .kilometers: kilometers
        }
    }
}
