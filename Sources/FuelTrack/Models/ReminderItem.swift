import Foundation
import SwiftData

@Model
final class ReminderItem {
    var id: UUID
    var title: String
    var dueDate: Date?
    var dueOdometer: Double?
    var note: String
    var isCompleted: Bool
    var createdAt: Date

    var vehicle: Vehicle?

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        dueOdometer: Double? = nil,
        note: String = "",
        isCompleted: Bool = false,
        createdAt: Date = .now,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.dueOdometer = dueOdometer
        self.note = note
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.vehicle = vehicle
    }
}
