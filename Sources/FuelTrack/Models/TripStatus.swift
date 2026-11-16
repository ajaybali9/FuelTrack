import Foundation

enum TripStatus: String, CaseIterable, Codable, Sendable {
    case active
    case completed
    case cancelled
}