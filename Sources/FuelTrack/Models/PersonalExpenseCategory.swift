import Foundation

enum PersonalExpenseCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case food
    case groceries
    case shopping
    case bills
    case rent
    case transport
    case health
    case entertainment
    case travel
    case education
    case gifts
    case subscriptions
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: "Food & dining"
        case .groceries: "Groceries"
        case .shopping: "Shopping"
        case .bills: "Bills & utilities"
        case .rent: "Rent / mortgage"
        case .transport: "Transport"
        case .health: "Health"
        case .entertainment: "Entertainment"
        case .travel: "Travel"
        case .education: "Education"
        case .gifts: "Gifts"
        case .subscriptions: "Subscriptions"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .food: "fork.knife"
        case .groceries: "cart"
        case .shopping: "bag"
        case .bills: "bolt"
        case .rent: "house"
        case .transport: "bus"
        case .health: "heart"
        case .entertainment: "ticket"
        case .travel: "airplane"
        case .education: "book"
        case .gifts: "gift"
        case .subscriptions: "repeat"
        case .other: "ellipsis.circle"
        }
    }
}
