import Foundation

/// Full on-device backup of FuelTrack data (vehicles, fuel, car + personal spend, budgets, reminders).
enum FuelTrackBackupExporter {
    static let formatName = "FuelTrackBackup"
    static let formatVersion = 1

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
                .map(savedStationBackup)
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
