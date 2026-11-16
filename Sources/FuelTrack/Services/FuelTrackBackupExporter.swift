import Foundation

/// Full on-device backup of FuelTrack data (vehicles, fuel, car + personal spend, budgets, reminders).
enum FuelTrackBackupExporter {
    static let formatName = "FuelTrackBackup"
    static let formatVersion = 2

    struct Snapshot: Codable, Sendable {
        var format: String
        var version: Int
        var exportedAt: Date
        var vehicles: [VehicleBackup]
        var personalExpenses: [PersonalExpenseBackup]
        var personalBudgets: [PersonalBudgetBackup]
        var customCategories: [CustomCategoryBackup]
    }

    struct VehicleBackup: Codable, Sendable {
        var id: UUID
        var name: String
        var make: String
        var model: String
        var fuelType: String
        var odometerUnit: String
        var currencyCode: String
        var notes: String
        var createdAt: Date
        var registrationPlate: String
        var colour: String
        var yearOfManufacture: Int
        var engineCapacityCC: Int
        var co2Emissions: Int
        var motStatus: String
        var motExpiry: Date?
        var taxStatus: String
        var taxDueDate: Date?
        var insuranceProvider: String
        var insuranceExpiry: Date?
        var lastComplianceRefresh: Date?
        var fillUps: [FillUpBackup]
        var costs: [CarCostBackup]
        var reminders: [ReminderBackup]
        var savedStations: [SavedStationBackup]
        var trips: [TripBackup]

        enum CodingKeys: String, CodingKey {
            case id, name, make, model, fuelType, odometerUnit, currencyCode, notes, createdAt
            case registrationPlate, colour, yearOfManufacture, engineCapacityCC, co2Emissions
            case motStatus, motExpiry, taxStatus, taxDueDate, insuranceProvider, insuranceExpiry
            case lastComplianceRefresh, fillUps, costs, reminders, savedStations, trips
        }

        init(
            id: UUID,
            name: String,
            make: String,
            model: String,
            fuelType: String,
            odometerUnit: String,
            currencyCode: String,
            notes: String,
            createdAt: Date,
            registrationPlate: String,
            colour: String,
            yearOfManufacture: Int,
            engineCapacityCC: Int,
            co2Emissions: Int,
            motStatus: String,
            motExpiry: Date?,
            taxStatus: String,
            taxDueDate: Date?,
            insuranceProvider: String,
            insuranceExpiry: Date?,
            lastComplianceRefresh: Date?,
            fillUps: [FillUpBackup],
            costs: [CarCostBackup],
            reminders: [ReminderBackup],
            savedStations: [SavedStationBackup],
            trips: [TripBackup]
        ) {
            self.id = id
            self.name = name
            self.make = make
            self.model = model
            self.fuelType = fuelType
            self.odometerUnit = odometerUnit
            self.currencyCode = currencyCode
            self.notes = notes
            self.createdAt = createdAt
            self.registrationPlate = registrationPlate
            self.colour = colour
            self.yearOfManufacture = yearOfManufacture
            self.engineCapacityCC = engineCapacityCC
            self.co2Emissions = co2Emissions
            self.motStatus = motStatus
            self.motExpiry = motExpiry
            self.taxStatus = taxStatus
            self.taxDueDate = taxDueDate
            self.insuranceProvider = insuranceProvider
            self.insuranceExpiry = insuranceExpiry
            self.lastComplianceRefresh = lastComplianceRefresh
            self.fillUps = fillUps
            self.costs = costs
            self.reminders = reminders
            self.savedStations = savedStations
            self.trips = trips
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            make = try c.decode(String.self, forKey: .make)
            model = try c.decode(String.self, forKey: .model)
            fuelType = try c.decode(String.self, forKey: .fuelType)
            odometerUnit = try c.decode(String.self, forKey: .odometerUnit)
            currencyCode = try c.decode(String.self, forKey: .currencyCode)
            notes = try c.decode(String.self, forKey: .notes)
            createdAt = try c.decode(Date.self, forKey: .createdAt)
            registrationPlate = try c.decode(String.self, forKey: .registrationPlate)
            colour = try c.decode(String.self, forKey: .colour)
            yearOfManufacture = try c.decode(Int.self, forKey: .yearOfManufacture)
            engineCapacityCC = try c.decode(Int.self, forKey: .engineCapacityCC)
            co2Emissions = try c.decode(Int.self, forKey: .co2Emissions)
            motStatus = try c.decode(String.self, forKey: .motStatus)
            motExpiry = try c.decodeIfPresent(Date.self, forKey: .motExpiry)
            taxStatus = try c.decode(String.self, forKey: .taxStatus)
            taxDueDate = try c.decodeIfPresent(Date.self, forKey: .taxDueDate)
            insuranceProvider = try c.decode(String.self, forKey: .insuranceProvider)
            insuranceExpiry = try c.decodeIfPresent(Date.self, forKey: .insuranceExpiry)
            lastComplianceRefresh = try c.decodeIfPresent(Date.self, forKey: .lastComplianceRefresh)
            fillUps = try c.decode([FillUpBackup].self, forKey: .fillUps)
            costs = try c.decode([CarCostBackup].self, forKey: .costs)
            reminders = try c.decode([ReminderBackup].self, forKey: .reminders)
            savedStations = try c.decode([SavedStationBackup].self, forKey: .savedStations)
            trips = try c.decodeIfPresent([TripBackup].self, forKey: .trips) ?? []
        }
    }

    struct TripBackup: Codable, Sendable {
        var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var status: String
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
        var points: [TripPointBackup]
    }

    struct TripPointBackup: Codable, Sendable {
        var id: UUID
        var recordedAt: Date
        var latitude: Double
        var longitude: Double
        var speedMps: Double?
        var horizontalAccuracy: Double?
        var sequence: Int
    }

    struct FillUpBackup: Codable, Sendable {
        var id: UUID
        var date: Date
        var odometer: Double
        var liters: Double
        var totalCost: Double
        var currencyCode: String
        var isFullTank: Bool
        var skipped: Bool
        var station: String
        var stationExternalId: String
        var latitude: Double?
        var longitude: Double?
        var note: String
        var fuelType: String
        var createdAt: Date
    }

    struct CarCostBackup: Codable, Sendable {
        var id: UUID
        var title: String
        var date: Date
        var odometer: Double?
        var amount: Double
        var currencyCode: String
        var category: String
        var note: String
        var createdAt: Date
    }

    struct ReminderBackup: Codable, Sendable {
        var id: UUID
        var title: String
        var dueDate: Date?
        var dueOdometer: Double?
        var note: String
        var isCompleted: Bool
        var createdAt: Date
    }

    struct SavedStationBackup: Codable, Sendable {
        var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var externalId: String
        var note: String
        var createdAt: Date
    }

    struct PersonalExpenseBackup: Codable, Sendable {
        var id: UUID
        var title: String
        var date: Date
        var amount: Double
        var currencyCode: String
        var category: String
        var note: String
        var paymentMethod: String
        var createdAt: Date
    }

    struct PersonalBudgetBackup: Codable, Sendable {
        var id: UUID
        var category: String
        var monthlyLimit: Double
        var currencyCode: String
        var createdAt: Date
    }

    struct CustomCategoryBackup: Codable, Sendable {
        var id: UUID
        var name: String
        var systemImage: String
        var scope: String
        var createdAt: Date
    }

    static func makeSnapshot(
        vehicles: [Vehicle],
        personalExpenses: [PersonalExpense],
        personalBudgets: [PersonalBudget],
        customCategories: [CustomExpenseCategory]
    ) -> Snapshot {
        Snapshot(
            format: formatName,
            version: formatVersion,
            exportedAt: .now,
            vehicles: vehicles
                .sorted { $0.createdAt < $1.createdAt }
                .map(vehicleBackup),
            personalExpenses: personalExpenses
                .sorted { $0.date > $1.date }
                .map(personalExpenseBackup),
            personalBudgets: personalBudgets
                .sorted { $0.createdAt < $1.createdAt }
                .map(personalBudgetBackup),
            customCategories: customCategories
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map(customCategoryBackup)
        )
    }

    static func exportJSON(
        vehicles: [Vehicle],
        personalExpenses: [PersonalExpense],
        personalBudgets: [PersonalBudget],
        customCategories: [CustomExpenseCategory]
    ) throws -> Data {
        let snapshot = makeSnapshot(
            vehicles: vehicles,
            personalExpenses: personalExpenses,
            personalBudgets: personalBudgets,
            customCategories: customCategories
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    static func writeBackupFile(
        vehicles: [Vehicle],
        personalExpenses: [PersonalExpense],
        personalBudgets: [PersonalBudget],
        customCategories: [CustomExpenseCategory]
    ) throws -> URL {
        let data = try exportJSON(
            vehicles: vehicles,
            personalExpenses: personalExpenses,
            personalBudgets: personalBudgets,
            customCategories: customCategories
        )
        let stamp = isoFileStamp(Date.now)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FuelTrack-Backup-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func isoFileStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }

    private static func vehicleBackup(_ vehicle: Vehicle) -> VehicleBackup {
        VehicleBackup(
            id: vehicle.id,
            name: vehicle.name,
            make: vehicle.make,
            model: vehicle.model,
            fuelType: vehicle.fuelType.rawValue,
            odometerUnit: vehicle.odometerUnit.rawValue,
            currencyCode: vehicle.currencyCode.rawValue,
            notes: vehicle.notes,
            createdAt: vehicle.createdAt,
            registrationPlate: vehicle.registrationPlate,
            colour: vehicle.colour,
            yearOfManufacture: vehicle.yearOfManufacture,
            engineCapacityCC: vehicle.engineCapacityCC,
            co2Emissions: vehicle.co2Emissions,
            motStatus: vehicle.motStatus,
            motExpiry: vehicle.motExpiry,
            taxStatus: vehicle.taxStatus,
            taxDueDate: vehicle.taxDueDate,
            insuranceProvider: vehicle.insuranceProvider,
            insuranceExpiry: vehicle.insuranceExpiry,
            lastComplianceRefresh: vehicle.lastComplianceRefresh,
            fillUps: vehicle.sortedFillUps.map(fillUpBackup),
            costs: vehicle.sortedCosts.map(carCostBackup),
            reminders: vehicle.reminders
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                .map(reminderBackup),
            savedStations: vehicle.savedStations
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map(savedStationBackup),
            trips: vehicle.trips
                .sorted { $0.startedAt < $1.startedAt }
                .map(tripBackup)
        )
    }

    private static func tripBackup(_ trip: Trip) -> TripBackup {
        TripBackup(
            id: trip.id,
            startedAt: trip.startedAt,
            endedAt: trip.endedAt,
            status: trip.statusRaw,
            distance: trip.distance,
            durationSeconds: trip.durationSeconds,
            averageSpeed: trip.averageSpeed,
            maxSpeed: trip.maxSpeed,
            estimatedMPG: trip.estimatedMPG,
            estimatedLitersPer100km: trip.estimatedLitersPer100km,
            startLatitude: trip.startLatitude,
            startLongitude: trip.startLongitude,
            endLatitude: trip.endLatitude,
            endLongitude: trip.endLongitude,
            note: trip.note,
            createdAt: trip.createdAt,
            points: trip.sortedPoints.map(tripPointBackup)
        )
    }

    private static func tripPointBackup(_ point: TripPoint) -> TripPointBackup {
        TripPointBackup(
            id: point.id,
            recordedAt: point.recordedAt,
            latitude: point.latitude,
            longitude: point.longitude,
            speedMps: point.speedMps,
            horizontalAccuracy: point.horizontalAccuracy,
            sequence: point.sequence
        )
    }

    private static func fillUpBackup(_ fill: FillUp) -> FillUpBackup {
        FillUpBackup(
            id: fill.id,
            date: fill.date,
            odometer: fill.odometer,
            liters: fill.liters,
            totalCost: fill.totalCost,
            currencyCode: fill.currencyCode.rawValue,
            isFullTank: fill.isFullTank,
            skipped: fill.skipped,
            station: fill.station,
            stationExternalId: fill.stationExternalId,
            latitude: fill.latitude,
            longitude: fill.longitude,
            note: fill.note,
            fuelType: fill.fuelType.rawValue,
            createdAt: fill.createdAt
        )
    }

    private static func carCostBackup(_ cost: CarCost) -> CarCostBackup {
        CarCostBackup(
            id: cost.id,
            title: cost.title,
            date: cost.date,
            odometer: cost.odometer,
            amount: cost.amount,
            currencyCode: cost.currencyCode.rawValue,
            category: cost.categoryKey,
            note: cost.note,
            createdAt: cost.createdAt
        )
    }

    private static func reminderBackup(_ item: ReminderItem) -> ReminderBackup {
        ReminderBackup(
            id: item.id,
            title: item.title,
            dueDate: item.dueDate,
            dueOdometer: item.dueOdometer,
            note: item.note,
            isCompleted: item.isCompleted,
            createdAt: item.createdAt
        )
    }

    private static func savedStationBackup(_ place: SavedStation) -> SavedStationBackup {
        SavedStationBackup(
            id: place.id,
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            externalId: place.externalId,
            note: place.note,
            createdAt: place.createdAt
        )
    }

    private static func personalExpenseBackup(_ expense: PersonalExpense) -> PersonalExpenseBackup {
        PersonalExpenseBackup(
            id: expense.id,
            title: expense.title,
            date: expense.date,
            amount: expense.amount,
            currencyCode: expense.currencyCode.rawValue,
            category: expense.categoryKey,
            note: expense.note,
            paymentMethod: expense.paymentMethod,
            createdAt: expense.createdAt
        )
    }

    private static func personalBudgetBackup(_ budget: PersonalBudget) -> PersonalBudgetBackup {
        PersonalBudgetBackup(
            id: budget.id,
            category: budget.categoryRaw,
            monthlyLimit: budget.monthlyLimit,
            currencyCode: budget.currencyCode.rawValue,
            createdAt: budget.createdAt
        )
    }

    private static func customCategoryBackup(_ category: CustomExpenseCategory) -> CustomCategoryBackup {
        CustomCategoryBackup(
            id: category.id,
            name: category.name,
            systemImage: category.systemImage,
            scope: category.scopeRaw,
            createdAt: category.createdAt
        )
    }
}
