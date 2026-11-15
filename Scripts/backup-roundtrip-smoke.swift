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

func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

let vehicleID = UUID()
let fillID = UUID()
let costID = UUID()
let expenseID = UUID()
let now = Date(timeIntervalSince1970: 1_700_000_000)

let original = Snapshot(
    format: "FuelTrackBackup",
    version: 1,
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
guard decoded.version == 1 else { fail("version") }
guard decoded.vehicles.count == 1 else { fail("vehicles count") }
guard decoded.vehicles[0].id == vehicleID else { fail("vehicle id") }
guard decoded.vehicles[0].fillUps.count == 1 else { fail("fillUps") }
guard decoded.vehicles[0].fillUps[0].id == fillID else { fail("fill id") }
guard decoded.vehicles[0].costs[0].id == costID else { fail("cost id") }
guard decoded.personalExpenses[0].id == expenseID else { fail("expense id") }
guard abs(decoded.vehicles[0].fillUps[0].liters - 40.5) < 0.001 else { fail("liters") }
guard decoded.personalBudgets[0].monthlyLimit == 1500 else { fail("budget") }
guard decoded.customCategories[0].name == "Tyres" else { fail("category") }

// Reject wrong format the way the app importer does.
struct Loose: Codable { var format: String; var version: Int }
let bad = try! JSONEncoder().encode(Loose(format: "Other", version: 1))
let badDecoded = try! JSONDecoder().decode(Loose.self, from: bad)
guard badDecoded.format != "FuelTrackBackup" else { fail("expected wrong format") }

print("OK backup JSON roundtrip (\(data.count) bytes)")
print("  vehicles=\(decoded.vehicles.count) fillUps=\(decoded.vehicles[0].fillUps.count) costs=\(decoded.vehicles[0].costs.count)")
print("  personalExpenses=\(decoded.personalExpenses.count) budgets=\(decoded.personalBudgets.count) categories=\(decoded.customCategories.count)")
