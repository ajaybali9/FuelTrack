import Foundation

enum CostCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case service
    case maintenance
    case insurance
    case mot
    case roadTax
    case registration
    case parking
    case wash
    case tolls
    case fines
    case tuning
    case other

    var id: String { rawValue }

    /// Match a Fuelio category name, including "Tickets/Fines" and "Road tax".
    static func fromFuelioName(_ name: String) -> CostCategory {
        let key = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "/", with: " ")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .joined(separator: " ")
        switch key {
        case "service": return .service
        case "maintenance": return .maintenance
        case "insurance": return .insurance
        case "mot": return .mot
        case "road tax", "tax": return .roadTax
        case "registration": return .registration
        case "parking": return .parking
        case "wash": return .wash
        case "tolls", "toll": return .tolls
        case "tickets fines", "fines", "tickets": return .fines
        case "tuning": return .tuning
        default: return .other
        }
    }

    var displayName: String {
        switch self {
        case .service: "Service"
        case .maintenance: "Maintenance"
        case .insurance: "Insurance"
        case .mot: "MOT"
        case .roadTax: "Road tax"
        case .registration: "Registration"
        case .parking: "Parking"
        case .wash: "Wash"
        case .tolls: "Tolls"
        case .fines: "Tickets / Fines"
        case .tuning: "Tuning"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .service: "wrench.and.screwdriver"
        case .maintenance: "screwdriver"
        case .insurance: "shield.checkered"
        case .mot: "checklist"
        case .roadTax: "sterlingsign.circle"
        case .registration: "doc.text"
        case .parking: "parkingsign.circle"
        case .wash: "drop"
        case .tolls: "road.lanes"
        case .fines: "exclamationmark.triangle"
        case .tuning: "gauge.with.dots.needle.67percent"
        case .other: "ellipsis.circle"
        }
    }
}
