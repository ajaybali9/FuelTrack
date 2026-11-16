#!/usr/bin/env swift
import Foundation

// Verifies FuelTrack backup JSON encode → decode roundtrip shape.
// Run: swift Scripts/backup-roundtrip-smoke.swift

struct Snapshot: Codable {
    var format: String
    var version: Int
    var exportedAt: Date
    var vehicles: [VehicleBackup]
    var personalExpenses: [PersonalExpenseBackup]
    var personalBudgets: [PersonalBudgetBackup]
    var customCategories: [CustomCategoryBackup]
}

struct VehicleBackup: Codable {
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
}

struct TripBackup: Codable {
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

struct TripPointBackup: Codable {
    var id: UUID
    var recordedAt: Date
    var latitude: Double
    var longitude: Double
    var speedMps: Double?
    var horizontalAccuracy: Double?
    var sequence: Int
}

struct FillUpBackup: Codable {
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

struct CarCostBackup: Codable {
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

struct ReminderBackup: Codable {
    var id: UUID
    var title: String
    var dueDate: Date?
    var dueOdometer: Double?
    var note: String
    var isCompleted: Bool
    var createdAt: Date
}

struct SavedStationBackup: Codable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var externalId: String
    var note: String
    var createdAt: Date
}

struct PersonalExpenseBackup: Codable {
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

struct PersonalBudgetBackup: Codable {
    var id: UUID
    var category: String
    var monthlyLimit: Double
    var currencyCode: String
    var createdAt: Date
}

struct CustomCategoryBackup: Codable {
    var id: UUID
    var name: String
    var systemImage: String
    var scope: String
    var createdAt: Date
}

/// v1 backups omit `trips`; importer treats missing as empty.
struct VehicleBackupV1: Codable {
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

struct VehicleBackupV2Compat: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, make, model, fuelType, odometerUnit, currencyCode, notes, createdAt
        case registrationPlate, colour, yearOfManufacture, engineCapacityCC, co2Emissions
        case motStatus, motExpiry, taxStatus, taxDueDate, insuranceProvider, insuranceExpiry
        case lastComplianceRefresh, fillUps, costs, reminders, savedStations, trips
    }

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

func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

let vehicleID = UUID()
let fillID = UUID()
let costID = UUID()
let expenseID = UUID()
let tripID = UUID()
let point0ID = UUID()
let point1ID = UUID()
let now = Date(timeIntervalSince1970: 1_700_000_000)
let tripEnd = now.addingTimeInterval(900)

let original = Snapshot(
    format: "FuelTrackBackup",
    version: 2,
    exportedAt: now,
    vehicles: [
        VehicleBackup(
            id: vehicleID,
            name: "Mazda3",
            make: "Mazda",
            model: "Mazda3",
            fuelType: "petrolE10",
            odometerUnit: "miles",
            currencyCode: "GBP",
            notes: "daily",
            createdAt: now,
            registrationPlate: "DC66NWT",
            colour: "Blue",
            yearOfManufacture: 2017,
            engineCapacityCC: 2000,
            co2Emissions: 140,
            motStatus: "Valid",
            motExpiry: now,
            taxStatus: "Taxed",
            taxDueDate: now,
            insuranceProvider: "Direct",
            insuranceExpiry: now,
            lastComplianceRefresh: now,
            fillUps: [
                FillUpBackup(
                    id: fillID,
                    date: now,
                    odometer: 45000,
                    liters: 40.5,
                    totalCost: 58.2,
                    currencyCode: "GBP",
                    isFullTank: true,
                    skipped: false,
                    station: "Tesco · Basingstoke",
                    stationExternalId: "abc",
                    latitude: 51.26,
                    longitude: -1.08,
                    note: "full",
                    fuelType: "petrolE10",
                    createdAt: now
                )
            ],
            costs: [
                CarCostBackup(
                    id: costID,
                    title: "Service",
                    date: now,
                    odometer: 44000,
                    amount: 220,
                    currencyCode: "GBP",
                    category: "service",
                    note: "",
                    createdAt: now
                )
            ],
            reminders: [
                ReminderBackup(
                    id: UUID(),
                    title: "MOT",
                    dueDate: now,
                    dueOdometer: nil,
                    note: "",
                    isCompleted: false,
                    createdAt: now
                )
            ],
            savedStations: [
                SavedStationBackup(
                    id: UUID(),
                    name: "Home Shell",
                    latitude: 51.25,
                    longitude: -1.09,
                    externalId: "",
                    note: "fav",
                    createdAt: now
                )
            ],
            trips: [
                TripBackup(
                    id: tripID,
                    startedAt: now,
                    endedAt: tripEnd,
                    status: "completed",
                    distance: 12.4,
                    durationSeconds: 900,
                    averageSpeed: 49.6,
                    maxSpeed: 65.0,
                    estimatedMPG: 38.2,
                    estimatedLitersPer100km: nil,
                    startLatitude: 51.26,
                    startLongitude: -1.08,
                    endLatitude: 51.28,
                    endLongitude: -1.02,
                    note: "commute",
                    createdAt: now,
                    points: [
                        TripPointBackup(
                            id: point0ID,
                            recordedAt: now,
                            latitude: 51.26,
                            longitude: -1.08,
                            speedMps: 12,
                            horizontalAccuracy: 8,
                            sequence: 0
                        ),
                        TripPointBackup(
                            id: point1ID,
                            recordedAt: tripEnd,
                            latitude: 51.28,
                            longitude: -1.02,
                            speedMps: 18,
                            horizontalAccuracy: 6,
                            sequence: 1
                        )
                    ]
                )
            ]
        )
    ],
    personalExpenses: [
        PersonalExpenseBackup(
            id: expenseID,
            title: "Groceries",
            date: now,
            amount: 42.5,
            currencyCode: "GBP",
            category: "groceries",
            note: "",
            paymentMethod: "card",
            createdAt: now
        )
    ],
    personalBudgets: [
        PersonalBudgetBackup(
            id: UUID(),
            category: "",
            monthlyLimit: 1500,
            currencyCode: "GBP",
            createdAt: now
        )
    ],
    customCategories: [
        CustomCategoryBackup(
            id: UUID(),
            name: "Tyres",
            systemImage: "circle",
            scope: "car",
            createdAt: now
        )
    ]
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
encoder.dateEncodingStrategy = .iso8601
guard let data = try? encoder.encode(original) else {
    fail("encode")
}

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
guard let decoded = try? decoder.decode(Snapshot.self, from: data) else {
    fail("decode")
}

guard decoded.format == "FuelTrackBackup" else { fail("format") }
guard decoded.version == 2 else { fail("version") }
guard decoded.vehicles.count == 1 else { fail("vehicles count") }
guard decoded.vehicles[0].id == vehicleID else { fail("vehicle id") }
guard decoded.vehicles[0].fillUps.count == 1 else { fail("fillUps") }
guard decoded.vehicles[0].fillUps[0].id == fillID else { fail("fill id") }
guard decoded.vehicles[0].costs[0].id == costID else { fail("cost id") }
guard decoded.personalExpenses[0].id == expenseID else { fail("expense id") }
guard abs(decoded.vehicles[0].fillUps[0].liters - 40.5) < 0.001 else { fail("liters") }
guard decoded.personalBudgets[0].monthlyLimit == 1500 else { fail("budget") }
guard decoded.customCategories[0].name == "Tyres" else { fail("category") }
guard decoded.vehicles[0].trips.count == 1 else { fail("trips count") }
guard decoded.vehicles[0].trips[0].id == tripID else { fail("trip id") }
guard decoded.vehicles[0].trips[0].points.count == 2 else { fail("trip points") }
guard decoded.vehicles[0].trips[0].points[0].id == point0ID else { fail("point id") }

// v1 vehicle JSON without `trips` decodes with empty trips (importer compat).
let v1Vehicle = VehicleBackupV1(
    id: UUID(),
    name: "Legacy",
    make: "",
    model: "",
    fuelType: "petrolE10",
    odometerUnit: "miles",
    currencyCode: "GBP",
    notes: "",
    createdAt: now,
    registrationPlate: "",
    colour: "",
    yearOfManufacture: 0,
    engineCapacityCC: 0,
    co2Emissions: 0,
    motStatus: "",
    motExpiry: nil,
    taxStatus: "",
    taxDueDate: nil,
    insuranceProvider: "",
    insuranceExpiry: nil,
    lastComplianceRefresh: nil,
    fillUps: [],
    costs: [],
    reminders: [],
    savedStations: []
)
let v1Data = try! encoder.encode(v1Vehicle)
guard let v1Decoded = try? decoder.decode(VehicleBackupV2Compat.self, from: v1Data) else {
    fail("v1 vehicle decode")
}
guard v1Decoded.trips.isEmpty else { fail("v1 trips should default empty") }

// Reject wrong format the way the app importer does.
struct Loose: Codable { var format: String; var version: Int }
let bad = try! JSONEncoder().encode(Loose(format: "Other", version: 1))
let badDecoded = try! JSONDecoder().decode(Loose.self, from: bad)
guard badDecoded.format != "FuelTrackBackup" else { fail("expected wrong format") }

print("OK backup JSON roundtrip (\(data.count) bytes)")
print("  vehicles=\(decoded.vehicles.count) fillUps=\(decoded.vehicles[0].fillUps.count) costs=\(decoded.vehicles[0].costs.count)")
print("  trips=\(decoded.vehicles[0].trips.count) tripPoints=\(decoded.vehicles[0].trips[0].points.count)")
print("  personalExpenses=\(decoded.personalExpenses.count) budgets=\(decoded.personalBudgets.count) categories=\(decoded.customCategories.count)")