import Foundation
import SwiftUI

@MainActor
@Observable
final class ActiveVehicleStore {
    private static let storageKey = "activeVehicleID"

    var activeVehicleID: UUID? {
        didSet {
            if let activeVehicleID {
                UserDefaults.standard.set(activeVehicleID.uuidString, forKey: Self.storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.storageKey)
            }
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey) {
            activeVehicleID = UUID(uuidString: raw)
        }
    }

    func resolve(from vehicles: [Vehicle]) -> Vehicle? {
        if let activeVehicleID,
           let match = vehicles.first(where: { $0.id == activeVehicleID }) {
            return match
        }
        let first = vehicles.sorted { $0.createdAt < $1.createdAt }.first
        if let first, activeVehicleID != first.id {
            activeVehicleID = first.id
        }
        return first
    }

    func select(_ vehicle: Vehicle) {
        activeVehicleID = vehicle.id
    }
}
