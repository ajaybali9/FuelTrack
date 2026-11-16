import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var statusRaw: String
    var distance: Double
    var durationSeconds: Double
    var averageSpeed: Double
    var maxSpeed: Double
    var estimatedMPG: Double?
    var estimatedLitersPer100km: Double?
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var note: String
    var createdAt: Date

    var vehicle: Vehicle?

    @Relationship(deleteRule: .cascade, inverse: \TripPoint.trip)
    var points: [TripPoint]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        status: TripStatus = .active,
        distance: Double = 0,
        durationSeconds: Double = 0,
        averageSpeed: Double = 0,
        maxSpeed: Double = 0,
        estimatedMPG: Double? = nil,
        estimatedLitersPer100km: Double? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        note: String = "",
        createdAt: Date = .now,
        vehicle: Vehicle? = nil,
        points: [TripPoint] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.statusRaw = status.rawValue
        self.distance = distance
        self.durationSeconds = durationSeconds
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.estimatedMPG = estimatedMPG
        self.estimatedLitersPer100km = estimatedLitersPer100km
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.note = note
        self.createdAt = createdAt
        self.vehicle = vehicle
        self.points = points
    }

    var status: TripStatus {
        get { TripStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    var sortedPoints: [TripPoint] {
        points.sorted { $0.sequence < $1.sequence }
    }
}