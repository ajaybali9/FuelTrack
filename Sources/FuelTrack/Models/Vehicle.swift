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

    // UK compliance / DVLA
    var registrationPlate: String = ""
    var colour: String = ""
    var yearOfManufacture: Int = 0
    var engineCapacityCC: Int = 0
    var co2Emissions: Int = 0
    var motStatus: String = ""
    var motExpiry: Date?
    var taxStatus: String = ""
    var taxDueDate: Date?
    var insuranceProvider: String = ""
    var insuranceExpiry: Date?
    var lastComplianceRefresh: Date?

    @Relationship(deleteRule: .cascade, inverse: \FillUp.vehicle)
    var fillUps: [FillUp]

    @Relationship(deleteRule: .cascade, inverse: \CarCost.vehicle)
    var costs: [CarCost]

    @Relationship(deleteRule: .cascade, inverse: \ReminderItem.vehicle)
    var reminders: [ReminderItem]

    @Relationship(deleteRule: .cascade, inverse: \SavedStation.vehicle)
    var savedStations: [SavedStation]

    init(
        id: UUID = UUID(),
        name: String,
        make: String = "",
        model: String = "",
        fuelType: FuelType = .petrolE10,
        odometerUnit: OdometerUnit = .miles,
        currencyCode: CurrencyCode = .gbp,
        notes: String = "",
        registrationPlate: String = "",
        createdAt: Date = .now,
        fillUps: [FillUp] = [],
        costs: [CarCost] = [],
        reminders: [ReminderItem] = [],
        savedStations: [SavedStation] = []
    ) {
        self.id = id
        self.name = name
        self.make = make
        self.model = model
        self.fuelTypeRaw = fuelType.rawValue
        self.odometerUnitRaw = odometerUnit.rawValue
        self.currencyCodeRaw = currencyCode.rawValue
        self.notes = notes
        self.registrationPlate = DVLAVehicleService.cleanedRegistration(registrationPlate)
        self.createdAt = createdAt
        self.fillUps = fillUps
        self.costs = costs
        self.reminders = reminders
        self.savedStations = savedStations
    }

    var fuelType: FuelType {
        get { FuelType.fromStored(fuelTypeRaw) }
        set { fuelTypeRaw = newValue == .petrol ? FuelType.petrolE10.rawValue : newValue.rawValue }
    }

    var odometerUnit: OdometerUnit {
        get { OdometerUnit(rawValue: odometerUnitRaw) ?? .miles }
        set { odometerUnitRaw = newValue.rawValue }
    }

    var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) ?? .gbp }
        set { currencyCodeRaw = newValue.rawValue }
    }

    var displayPlate: String {
        let cleaned = DVLAVehicleService.cleanedRegistration(registrationPlate)
        guard cleaned.count > 4 else { return cleaned }
        let split = cleaned.index(cleaned.endIndex, offsetBy: -3)
        return "\(cleaned[..<split]) \(cleaned[split...])"
    }

    var displaySubtitle: String {
        var parts = [make, model].filter { !$0.isEmpty }
        if !registrationPlate.isEmpty {
            parts.insert(displayPlate, at: 0)
        }
        if parts.isEmpty { return fuelType.displayName }
        return parts.joined(separator: " · ")
    }

    var sortedFillUps: [FillUp] {
        fillUps.sorted {
            if $0.odometer != $1.odometer {
                return $0.odometer < $1.odometer
            }
            return $0.date < $1.date
        }
    }

    var sortedCosts: [CarCost] {
        costs.sorted { $0.date > $1.date }
    }

    var openReminders: [ReminderItem] {
        reminders.filter { !$0.isCompleted }.sorted {
            ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }
    }

    var latestOdometer: Double? {
        sortedFillUps.last?.odometer
    }

    var costsThisMonth: Double {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return costs.filter { $0.date >= start }.reduce(0) { $0 + $1.amount }
    }

    var costsThisYear: Double {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year], from: .now)) ?? .now
        return costs.filter { $0.date >= start }.reduce(0) { $0 + $1.amount }
    }

    var costsAllTime: Double {
        costs.reduce(0) { $0 + $1.amount }
    }

    /// Fuel + car costs for the current calendar year.
    var totalCarSpendThisYear: Double {
        let fuelYear = FuelStats.compute(vehicle: self).spendThisYear
        return fuelYear + costsThisYear
    }

    /// Fuel + car costs since the first log for this vehicle.
    var totalCarSpendAllTime: Double {
        let stats = FuelStats.compute(vehicle: self)
        return stats.totalSpend + costsAllTime
    }

    var motIsValid: Bool {
        motStatus.localizedCaseInsensitiveContains("valid")
    }

    var taxIsValid: Bool {
        let status = taxStatus.lowercased()
        if status.contains("untaxed") || status.contains("sorn") || status.contains("not taxed") {
            return false
        }
        return status.contains("taxed")
    }

    func applyDVLA(_ details: DVLAVehicleDetails) {
        registrationPlate = details.registrationNumber
        if let apiMake = details.make, !apiMake.isEmpty {
            make = apiMake.capitalized
        }
        if let colour = details.colour { self.colour = colour.capitalized }
        if let year = details.yearOfManufacture { yearOfManufacture = year }
        if let cc = details.engineCapacity { engineCapacityCC = cc }
        if let co2 = details.co2Emissions { co2Emissions = co2 }
        motStatus = details.motStatus ?? motStatus
        motExpiry = details.motExpiry ?? motExpiry
        taxStatus = details.taxStatus ?? taxStatus
        taxDueDate = details.taxDueDate ?? taxDueDate
        lastComplianceRefresh = .now

        if let fuel = details.fuelType?.uppercased() {
            if fuel.contains("DIESEL") {
                fuelType = .diesel
            } else if fuel.contains("ELECTRIC") {
                fuelType = .electric
            } else if fuel.contains("HYBRID") {
                fuelType = .hybrid
            } else if fuel.contains("PETROL") || fuel.contains("UNLEADED") {
                fuelType = .petrolE10
            }
        }
    }

    static func daysUntil(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.startOfDay(for: date)
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }
}
