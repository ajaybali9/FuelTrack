import Foundation
import SwiftData

@Model
final class FillUp {
    var id: UUID
    var date: Date
    var odometer: Double
    var liters: Double
    var totalCost: Double
    var currencyCodeRaw: String
    var isFullTank: Bool
    var skipped: Bool
    var station: String
    var note: String
    var fuelTypeRaw: String = ""
    var createdAt: Date

    var vehicle: Vehicle?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        odometer: Double,
        liters: Double,
        totalCost: Double,
        currencyCode: CurrencyCode = .gbp,
        isFullTank: Bool = true,
        skipped: Bool = false,
        station: String = "",
        note: String = "",
        fuelType: FuelType? = nil,
        createdAt: Date = .now,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.date = date
        self.odometer = odometer
        self.liters = liters
        self.totalCost = totalCost
        self.currencyCodeRaw = currencyCode.rawValue
        self.isFullTank = isFullTank
        self.skipped = skipped
        self.station = station
        self.note = note
        self.fuelTypeRaw = fuelType?.rawValue ?? ""
        self.createdAt = createdAt
        self.vehicle = vehicle
    }

    var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) ?? .gbp }
        set { currencyCodeRaw = newValue.rawValue }
    }

    var fuelType: FuelType {
        get {
            if fuelTypeRaw.isEmpty {
                return vehicle?.fuelType ?? .petrolE10
            }
            return FuelType.fromStored(fuelTypeRaw)
        }
        set {
            fuelTypeRaw = newValue == .petrol ? FuelType.petrolE10.rawValue : newValue.rawValue
        }
    }

    var pricePerLiter: Double? {
        guard liters > 0 else { return nil }
        return totalCost / liters
    }
}
