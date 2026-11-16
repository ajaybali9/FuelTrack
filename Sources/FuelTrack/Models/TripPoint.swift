import Foundation
import SwiftData

@Model
final class TripPoint {
    var id: UUID
    var recordedAt: Date
    var latitude: Double
    var longitude: Double
    var speedMps: Double?
    var horizontalAccuracy: Double?
    var sequence: Int
    var trip: Trip?

    init(
        id: UUID = UUID(),
        recordedAt: Date = .now,
        latitude: Double,
        longitude: Double,
        speedMps: Double? = nil,
        horizontalAccuracy: Double? = nil,
        sequence: Int,
        trip: Trip? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.latitude = latitude
        self.longitude = longitude
        self.speedMps = speedMps
        self.horizontalAccuracy = horizontalAccuracy
        self.sequence = sequence
        self.trip = trip
    }
}