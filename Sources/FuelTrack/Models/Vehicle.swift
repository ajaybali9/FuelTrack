import Foundation
import SwiftData

@Model
final class Vehicle {
    var id: UUID
    var name: String
    var make: String
    var model: String
    var fuelTypeRaw: String
    var odometerUnitRaw: String
    var currencyCodeRaw: String
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \FillUp.vehicle)
    var fillUps: [FillUp]

    init(
        id: UUID = UUID(),
        name: String,
        make: String = "",
        model: String = "",
        fuelType: FuelType = .petrol,
        odometerUnit: OdometerUnit = .miles,
        currencyCode: CurrencyCode = .gbp,
        notes: String = "",
        createdAt: Date = .now,
        fillUps: [FillUp] = []
    ) {
        self.id = id
        self.name = name
        self.make = make
        self.model = model
        self.fuelTypeRaw = fuelType.rawValue
        self.odometerUnitRaw = odometerUnit.rawValue
        self.currencyCodeRaw = currencyCode.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.fillUps = fillUps
    }

    var fuelType: FuelType {
        get { FuelType(rawValue: fuelTypeRaw) ?? .other }
        set { fuelTypeRaw = newValue.rawValue }
    }

    var odometerUnit: OdometerUnit {
        get { OdometerUnit(rawValue: odometerUnitRaw) ?? .miles }
        set { odometerUnitRaw = newValue.rawValue }
    }

    var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) ?? .gbp }
        set { currencyCodeRaw = newValue.rawValue }
    }

    var displaySubtitle: String {
        let parts = [make, model].filter { !$0.isEmpty }
        if parts.isEmpty { return fuelType.displayName }
        return parts.joined(separator: " ") + " · " + fuelType.displayName
    }

    var sortedFillUps: [FillUp] {
        fillUps.sorted {
            if $0.odometer != $1.odometer {
                return $0.odometer < $1.odometer
            }
            return $0.date < $1.date
        }
    }

    var latestOdometer: Double? {
        sortedFillUps.last?.odometer
    }
}
