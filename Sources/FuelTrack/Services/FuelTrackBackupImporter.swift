import Foundation
import SwiftData

enum FuelTrackBackupImportError: LocalizedError {
    case invalidJSON
    case wrongFormat(String)
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "Couldn’t read this file as JSON."
        case .wrongFormat(let found):
            "Not a FuelTrack backup (found “\(found)”). Use Export backup from More."
        case .unsupportedVersion(let version):
            "Backup version \(version) isn’t supported by this app build."
        }
    }
}

struct FuelTrackBackupImportResult: Sendable {
    var vehiclesInserted: Int
    var vehiclesUpdated: Int
    var fillUps: Int
    var carCosts: Int
    var reminders: Int
    var savedStations: Int
    var personalExpenses: Int
    var personalBudgets: Int
    var customCategories: Int
    var trips: Int
    var tripPoints: Int

    var summary: String {
        var parts: [String] = []
        let vehicleTotal = vehiclesInserted + vehiclesUpdated
        if vehicleTotal > 0 {
            var line = "\(vehicleTotal) vehicle"
            if vehicleTotal != 1 { line += "s" }
            if vehiclesUpdated > 0 {
                line += " (\(vehiclesUpdated) updated)"
            }
            parts.append(line)
        }
        if fillUps > 0 {
            parts.append("\(fillUps) fill-up\(fillUps == 1 ? "" : "s")")
        }
        if carCosts > 0 {
            parts.append("\(carCosts) car cost\(carCosts == 1 ? "" : "s")")
        }
        if personalExpenses > 0 {
            parts.append("\(personalExpenses) personal expense\(personalExpenses == 1 ? "" : "s")")
        }
        if personalBudgets > 0 {
            parts.append("\(personalBudgets) budget\(personalBudgets == 1 ? "" : "s")")
        }
        if reminders > 0 {
            parts.append("\(reminders) reminder\(reminders == 1 ? "" : "s")")
        }
        if savedStations > 0 {
            parts.append("\(savedStations) fav station\(savedStations == 1 ? "" : "s")")
        }
        if customCategories > 0 {
            parts.append("\(customCategories) custom categor\(customCategories == 1 ? "y" : "ies")")
        }
        if trips > 0 {
            parts.append("\(trips) trip\(trips == 1 ? "" : "s")")
        }
        if tripPoints > 0 {
            parts.append("\(tripPoints) trip point\(tripPoints == 1 ? "" : "s")")
        }
        if parts.isEmpty { return "Backup contained no records." }
        return "Restored " + parts.joined(separator: ", ") + "."
    }
}

enum FuelTrackBackupImporter {
    static func parse(data: Data) throws -> FuelTrackBackupExporter.Snapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot: FuelTrackBackupExporter.Snapshot
        do {
            snapshot = try decoder.decode(FuelTrackBackupExporter.Snapshot.self, from: data)
        } catch {
            throw FuelTrackBackupImportError.invalidJSON
        }
        guard snapshot.format == FuelTrackBackupExporter.formatName else {
            throw FuelTrackBackupImportError.wrongFormat(snapshot.format)
        }
        guard snapshot.version >= 1, snapshot.version <= FuelTrackBackupExporter.formatVersion else {
            throw FuelTrackBackupImportError.unsupportedVersion(snapshot.version)
        }
        return snapshot
    }

    /// Merge backup into the store by UUID (insert missing, update existing). Safe to re-run.
    @MainActor
    static func importSnapshot(
        _ snapshot: FuelTrackBackupExporter.Snapshot,
        into modelContext: ModelContext
    ) throws -> FuelTrackBackupImportResult {
        var result = FuelTrackBackupImportResult(
            vehiclesInserted: 0,
            vehiclesUpdated: 0,
            fillUps: 0,
            carCosts: 0,
            reminders: 0,
            savedStations: 0,
            personalExpenses: 0,
            personalBudgets: 0,
            customCategories: 0,
            trips: 0,
            tripPoints: 0
        )

        for categoryBackup in snapshot.customCategories {
            upsertCustomCategory(categoryBackup, into: modelContext, result: &result)
        }

        for vehicleBackup in snapshot.vehicles {
            let vehicle = upsertVehicle(vehicleBackup, into: modelContext, result: &result)
            for fill in vehicleBackup.fillUps {
                upsertFillUp(fill, vehicle: vehicle, into: modelContext, result: &result)
            }
            for cost in vehicleBackup.costs {
                upsertCarCost(cost, vehicle: vehicle, into: modelContext, result: &result)
            }
            for reminder in vehicleBackup.reminders {
                upsertReminder(reminder, vehicle: vehicle, into: modelContext, result: &result)
            }
            for station in vehicleBackup.savedStations {
                upsertSavedStation(station, vehicle: vehicle, into: modelContext, result: &result)
            }
            for trip in vehicleBackup.trips {
                upsertTrip(trip, vehicle: vehicle, into: modelContext, result: &result)
            }
        }

        for expense in snapshot.personalExpenses {
            upsertPersonalExpense(expense, into: modelContext, result: &result)
        }
        for budget in snapshot.personalBudgets {
            upsertPersonalBudget(budget, into: modelContext, result: &result)
        }

        try modelContext.save()
        return result
    }

    @MainActor
    static func importData(_ data: Data, into modelContext: ModelContext) throws -> FuelTrackBackupImportResult {
        try importSnapshot(parse(data: data), into: modelContext)
    }

    // MARK: - Upserts

    @MainActor
    private static func upsertVehicle(
        _ backup: FuelTrackBackupExporter.VehicleBackup,
        into modelContext: ModelContext,
        result: inout FuelTrackBackupImportResult
    ) -> Vehicle {
        let id = backup.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == id })
        ).first

        let vehicle: Vehicle
        if let existing {
            vehicle = existing
            result.vehiclesUpdated += 1
        } else {
            vehicle = Vehicle(
                id: backup.id,
                name: backup.name,
                make: backup.make,
                model: backup.model,
                fuelType: FuelType.fromStored(backup.fuelType),
                odometerUnit: OdometerUnit(rawValue: backup.odometerUnit) ?? .miles,
                currencyCode: CurrencyCode(rawValue: backup.currencyCode) ?? .gbp,
                notes: backup.notes,
                registrationPlate: backup.registrationPlate,
                createdAt: backup.createdAt
            )
            modelContext.insert(vehicle)
            result.vehiclesInserted += 1
        }

        vehicle.name = backup.name
        vehicle.make = backup.make
        vehicle.model = backup.model
        vehicle.fuelType = FuelType.fromStored(backup.fuelType)
        vehicle.odometerUnit = OdometerUnit(rawValue: backup.odometerUnit) ?? .miles
        vehicle.currencyCode = CurrencyCode(rawValue: backup.currencyCode) ?? .gbp
        vehicle.notes = backup.notes
        vehicle.registrationPlate = backup.registrationPlate
        vehicle.colour = backup.colour
        vehicle.yearOfManufacture = backup.yearOfManufacture
        vehicle.engineCapacityCC = backup.engineCapacityCC
        vehicle.co2Emissions = backup.co2Emissions
        vehicle.motStatus = backup.motStatus
        vehicle.motExpiry = backup.motExpiry
        vehicle.taxStatus = backup.taxStatus
        vehicle.taxDueDate = backup.taxDueDate
        vehicle.insuranceProvider = backup.insuranceProvider
        vehicle.insuranceExpiry = backup.insuranceExpiry
        vehicle.lastComplianceRefresh = backup.lastComplianceRefresh
        return vehicle
    }

    @MainActor
    private static func upsertFillUp(
        _ backup: FuelTrackBackupExporter.FillUpBackup,
        vehicle: Vehicle,
        into modelContext: ModelContext,
        result: inout FuelTrackBackupImportResult
    ) {
        let id = backup.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<FillUp>(predicate: #Predicate { $0.id == id })
        ).first

        let fill: FillUp
        if let existing {
            fill = existing
        } else {
            fill = FillUp(
                id: backup.id,
                date: backup.date,
                odometer: backup.odometer,
                liters: backup.liters,
                totalCost: backup.totalCost,
                currencyCode: CurrencyCode(rawValue: backup.currencyCode) ?? .gbp,
                isFullTank: backup.isFullTank,
                skipped: backup.skipped,
                station: backup.station,
                note: backup.note,
                fuelType: FuelType.fromStored(backup.fuelType),
                latitude: backup.latitude,
                longitude: backup.longitude,
                stationExternalId: backup.stationExternalId,
                createdAt: backup.createdAt,
                vehicle: vehicle
            )
            modelContext.insert(fill)
        }

        fill.date = backup.date
        fill.odometer = backup.odometer
        fill.liters = backup.liters
        fill.totalCost = backup.totalCost
        fill.currencyCode = CurrencyCode(rawValue: backup.currencyCode) ?? .gbp
        fill.isFullTank = backup.isFullTank
        fill.skipped = backup.skipped
        fill.station = backup.station
        fill.stationExternalId = backup.stationExternalId
        fill.latitude = backup.latitude
        fill.longitude = backup.longitude
        fill.note = backup.note
        fill.fuelType = FuelType.fromStored(backup.fuelType)
        fill.vehicle = vehicle
        result.fillUps += 1
    }

    @MainActor
    private static func upsertCarCost(
        _ backup: FuelTrackBackupExporter.CarCostBackup,
        vehicle: Vehicle,
        into modelContext: ModelContext,
        result: inout FuelTrackBackupImportResult
    ) {
        let id = backup.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<CarCost>(predicate: #Predicate { $0.id == id })
        ).first

        let cost: CarCost
        if let existing {
            cost = existing
        } else {
            cost = CarCost(
                id: backup.id,
                title: backup.title,
                date: backup.date,
                odometer: backup.odometer,
                amount: backup.amount,
                currencyCode: CurrencyCode(rawValue: backup.currencyCode) ?? .gbp,
                categoryKey: backup.category,
                note: backup.note,
                createdAt: backup.createdAt,
                vehicle: vehicle
            )
            modelContext.insert(cost)
        }

        cost.title = backup.title
        cost.date = backup.date
        cost.odometer = backup.odometer
        cost.amount = backup.amount
        cost.currencyCode = CurrencyCode(rawValue: backup.currencyCode) ?? .gbp
        cost.categoryKey = backup.category
        cost.note = backup.note
        cost.vehicle = vehicle
        result.carCosts += 1
    }

    @MainActor
    private static func upsertReminder(
        _ backup: FuelTrackBackupExporter.ReminderBackup,
        vehicle: Vehicle,
        into modelContext: ModelContext,
        result: inout FuelTrackBackupImportResult
    ) {
        let id = backup.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<ReminderItem>(predicate: #Predicate { $0.id == id })
        ).first

        let item: ReminderItem
        if let existing {
            item = existing
        } else {
            item = ReminderItem(
                id: backup.id,
                title: backup.title,
                dueDate: backup.dueDate,
                dueOdometer: backup.dueOdometer,
                note: backup.note,
                isCompleted: backup.isCompleted,
                createdAt: backup.createdAt,
                vehicle: vehicle
            )
            modelContext.insert(item)
        }

        item.title = backup.title
        item.dueDate = backup.dueDate
        item.dueOdometer = backup.dueOdometer
        item.note = backup.note
        item.isCompleted = backup.isCompleted
        item.vehicle = vehicle
        result.reminders += 1
    }

    @MainActor
    private static func upsertSavedStation(
        _ backup: FuelTrackBackupExporter.SavedStationBackup,
        vehicle: Vehicle,
        into modelContext: ModelContext,
        result: inout FuelTrackBackupImportResult
    ) {
        let id = backup.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<SavedStation>(predicate: #Predicate { $0.id == id })
        ).first

        let place: SavedStation
        if let existing {
            place = existing
        } else {
            place = SavedStation(
                id: backup.id,
                name: backup.name,
                externalId: backup.externalId,
                latitude: backup.latitude,
                longitude: backup.longitude,
                note: backup.note,
                createdAt: backup.createdAt,
                vehicle: vehicle
            )
            modelContext.insert(place)
        }

        place.name = backup.name
        place.externalId = backup.externalId
        place.latitude = backup.latitude
        place.longitude = backup.longitude
        place.note = backup.note
        place.vehicle = vehicle
        result.savedStations += 1
    }

    @MainActor
    private static func upsertPersonalExpense(
        _ backup: FuelTrackBackupExporter.PersonalExpenseBackup,
        into modelContext: ModelContext,
        result: inout FuelTrackBackupImportResult
    ) {
        let id = backup.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<PersonalExpense>(predicate: #Predicate { $0.id == id })
        ).first

        let expense: PersonalExpense
        if let existing {
            expense = existing
        } else {
            expense = PersonalExpense(
                id: backup.id,
                title: backup.title,
                date: backup.date,
                amount: backup.amount,
                currencyCode: CurrencyCode(rawValue: backup.currencyCode) ?? .gbp,
                category: PersonalExpenseCategory(rawValue: backup.category) ?? .other,
                note: backup.note,
                paymentMethod: backup.paymentMethod,
                createdAt: backup.createdAt
            )
            modelContext.insert(expense)
        }

        expense.title = backup.title
        expense.date = backup.date
        expense.amount = backup.amount
        expense.currencyCode = CurrencyCode(rawValue: backup.currencyCode) ?? .gbp
        expense.categoryKey = backup.category
        expense.note = backup.note
        expense.paymentMethod = backup.paymentMethod
        result.personalExpenses += 1
    }

    @MainActor
    private static func upsertPersonalBudget(
        _ backup: FuelTrackBackupExporter.PersonalBudgetBackup,
        into modelContext: ModelContext,
        result: inout FuelTrackBackupImportResult
    ) {
        let id = backup.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<PersonalBudget>(predicate: #Predicate { $0.id == id })
        ).first

        let budget: PersonalBudget
        if let existing {
            budget = existing
        } else {
            let category = backup.category.isEmpty
                ? nil
                : PersonalExpenseCategory(rawValue: backup.category)
            budget = PersonalBudget(
                id: backup.id,
                category: category,
                monthlyLimit: backup.monthlyLimit,
                currencyCode: CurrencyCode(rawValue: backup.currencyCode) ?? .gbp,
                createdAt: backup.createdAt
            )
            modelContext.insert(budget)
        }

        budget.categoryRaw = backup.category
        budget.monthlyLimit = backup.monthlyLimit
        budget.currencyCode = CurrencyCode(rawValue: backup.currencyCode) ?? .gbp
        result.personalBudgets += 1
    }

    @MainActor
    private static func upsertTrip(
        _ backup: FuelTrackBackupExporter.TripBackup,
        vehicle: Vehicle,
        into modelContext: ModelContext,
        result: inout FuelTrackBackupImportResult
    ) {
        let id = backup.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<Trip>(predicate: #Predicate { $0.id == id })
        ).first

        let trip: Trip
        if let existing {
            trip = existing
            for point in trip.points {
                modelContext.delete(point)
            }
            trip.points = []
        } else {
            trip = Trip(
                id: backup.id,
                startedAt: backup.startedAt,
                endedAt: backup.endedAt,
                status: TripStatus(rawValue: backup.status) ?? .completed,
                distance: backup.distance,
                durationSeconds: backup.durationSeconds,
                averageSpeed: backup.averageSpeed,
                maxSpeed: backup.maxSpeed,
                estimatedMPG: backup.estimatedMPG,
                estimatedLitersPer100km: backup.estimatedLitersPer100km,
                startLatitude: backup.startLatitude,
                startLongitude: backup.startLongitude,
                endLatitude: backup.endLatitude,
                endLongitude: backup.endLongitude,
                note: backup.note,
                createdAt: backup.createdAt,
                vehicle: vehicle,
                points: []
            )
            modelContext.insert(trip)
        }

        trip.startedAt = backup.startedAt
        trip.endedAt = backup.endedAt
        trip.status = TripStatus(rawValue: backup.status) ?? .completed
        trip.distance = backup.distance
        trip.durationSeconds = backup.durationSeconds
        trip.averageSpeed = backup.averageSpeed
        trip.maxSpeed = backup.maxSpeed
        trip.estimatedMPG = backup.estimatedMPG
        trip.estimatedLitersPer100km = backup.estimatedLitersPer100km
        trip.startLatitude = backup.startLatitude
        trip.startLongitude = backup.startLongitude
        trip.endLatitude = backup.endLatitude
        trip.endLongitude = backup.endLongitude
        trip.note = backup.note
        trip.createdAt = backup.createdAt
        trip.vehicle = vehicle

        for pointBackup in backup.points {
            let point = TripPoint(
                id: pointBackup.id,
                recordedAt: pointBackup.recordedAt,
                latitude: pointBackup.latitude,
                longitude: pointBackup.longitude,
                speedMps: pointBackup.speedMps,
                horizontalAccuracy: pointBackup.horizontalAccuracy,
                sequence: pointBackup.sequence,
                trip: trip
            )
            modelContext.insert(point)
            trip.points.append(point)
            result.tripPoints += 1
        }

        result.trips += 1
    }

    @MainActor
    private static func upsertCustomCategory(
        _ backup: FuelTrackBackupExporter.CustomCategoryBackup,
        into modelContext: ModelContext,
        result: inout FuelTrackBackupImportResult
    ) {
        let id = backup.id
        let existing = try? modelContext.fetch(
            FetchDescriptor<CustomExpenseCategory>(predicate: #Predicate { $0.id == id })
        ).first

        let category: CustomExpenseCategory
        if let existing {
            category = existing
        } else {
            category = CustomExpenseCategory(
                id: backup.id,
                name: backup.name,
                systemImage: backup.systemImage,
                scope: CustomCategoryScope(rawValue: backup.scope) ?? .car,
                createdAt: backup.createdAt
            )
            modelContext.insert(category)
        }

        category.name = backup.name
        category.systemImage = backup.systemImage
        category.scope = CustomCategoryScope(rawValue: backup.scope) ?? .car
        result.customCategories += 1
    }
}
