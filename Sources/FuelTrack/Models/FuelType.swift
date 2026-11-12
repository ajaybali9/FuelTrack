import Foundation

enum FuelType: String, CaseIterable, Codable, Identifiable, Sendable {
    case petrol
    case diesel
    case electric
    case lpg
    case hybrid
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .petrol: "Petrol"
        case .diesel: "Diesel"
        case .electric: "Electric"
        case .lpg: "LPG"
        case .hybrid: "Hybrid"
        case .other: "Other"
        }
    }
}
