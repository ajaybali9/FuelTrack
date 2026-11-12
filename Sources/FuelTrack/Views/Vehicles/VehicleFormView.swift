import SwiftData
import SwiftUI

struct VehicleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue
    @AppStorage("defaultOdometerUnit") private var defaultOdometerUnit = OdometerUnit.miles.rawValue

    var vehicle: Vehicle?

    @State private var name = ""
    @State private var make = ""
    @State private var model = ""
    @State private var fuelType: FuelType = .petrol
    @State private var odometerUnit: OdometerUnit = .miles
    @State private var currencyCode: CurrencyCode = .gbp
    @State private var notes = ""
    @State private var makeActive = true

    private var isEditing: Bool { vehicle != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Vehicle") {
                TextField("Name", text: $name)
                TextField("Make", text: $make)
                TextField("Model", text: $model)
                Picker("Fuel type", selection: $fuelType) {
                    ForEach(FuelType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            Section("Preferences") {
                Picker("Odometer", selection: $odometerUnit) {
                    ForEach(OdometerUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                Picker("Currency", selection: $currencyCode) {
                    ForEach(CurrencyCode.allCases) { code in
                        Text(code.displayName).tag(code)
                    }
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            if !isEditing {
                Section {
                    Toggle("Set as active vehicle", isOn: $makeActive)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Vehicle" : "New Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        if let vehicle {
            name = vehicle.name
            make = vehicle.make
            model = vehicle.model
            fuelType = vehicle.fuelType
            odometerUnit = vehicle.odometerUnit
            currencyCode = vehicle.currencyCode
            notes = vehicle.notes
        } else {
            currencyCode = CurrencyCode(rawValue: defaultCurrencyCode) ?? .gbp
            odometerUnit = OdometerUnit(rawValue: defaultOdometerUnit) ?? .miles
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let vehicle {
            vehicle.name = trimmedName
            vehicle.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
            vehicle.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
            vehicle.fuelType = fuelType
            vehicle.odometerUnit = odometerUnit
            vehicle.currencyCode = currencyCode
            vehicle.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let created = Vehicle(
                name: trimmedName,
                make: make.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                fuelType: fuelType,
                odometerUnit: odometerUnit,
                currencyCode: currencyCode,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(created)
            if makeActive {
                activeVehicleStore.select(created)
            }
        }

        try? modelContext.save()
        if !isEditing {
            dismiss()
        }
    }
}
