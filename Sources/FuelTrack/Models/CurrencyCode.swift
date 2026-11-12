import Foundation

enum CurrencyCode: String, CaseIterable, Codable, Identifiable, Sendable {
    case gbp = "GBP"
    case inr = "INR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gbp: "British Pound (£)"
        case .inr: "Indian Rupee (₹)"
        }
    }

    var symbol: String {
        switch self {
        case .gbp: "£"
        case .inr: "₹"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .gbp: "en_GB"
        case .inr: "en_IN"
        }
    }
}
