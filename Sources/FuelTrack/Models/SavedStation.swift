import Foundation
import SwiftData

@Model
final class SavedStation {
    var id: UUID
    var name: String
    var externalId: String
    var latitude: Double
    var longitude: Double
    var note: String
    var createdAt: Date

    var vehicle: Vehicle?

    init(
        id: UUID = UUID(),
        name: String,
        externalId: String = "",
        latitude: Double,
        longitude: Double,
        note: String = "",
        createdAt: Date = .now,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.name = name
        self.externalId = externalId
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.createdAt = createdAt
        self.vehicle = vehicle
    }
}
