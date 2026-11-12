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
    @State private var registrationPlate = ""
    @State private var fuelType: FuelType = .petrolE10
    @State private var odometerUnit: OdometerUnit = .miles
    @State private var currencyCode: CurrencyCode = .gbp
    @State private var notes = ""
    @State private var makeActive = true
    @State private var showSavedAlert = false
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { vehicle != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Vehicle") {
                TextField("Name", text: $name)
                TextField("Registration", text: $registrationPlate)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Make", text: $make)
                TextField("Model", text: $model)
                Picker("Fuel type", selection: $fuelType) {
                    ForEach(FuelType.selectableCases) { type in
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

            if let vehicle {
                VehicleComplianceEditor(vehicle: vehicle)
            } else {
                Section("UK compliance") {
                    Text("Save the vehicle first, then open it again to refresh MOT & tax from DVLA and set insurance expiry.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

            if isEditing {
                Section {
                    Button("Delete Vehicle", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } footer: {
                    Text("Deletes this car and all of its fill-ups, costs, and reminders.")
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
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your vehicle details have been saved.")
        }
        .confirmationDialog(
            "Delete this vehicle?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Vehicle", role: .destructive) { deleteVehicle() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(name.isEmpty ? "the vehicle" : name) and all linked fill-ups, costs, and reminders. This can’t be undone.")
        }
        .onAppear(perform: load)
    }

    private func load() {
        if let vehicle {
            name = vehicle.name
            make = vehicle.make
            model = vehicle.model
            registrationPlate = vehicle.registrationPlate
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
        let plate = DVLAVehicleService.cleanedRegistration(registrationPlate)

        if let vehicle {
            vehicle.name = trimmedName
            vehicle.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
            vehicle.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
            vehicle.registrationPlate = plate
            vehicle.fuelType = fuelType
            vehicle.odometerUnit = odometerUnit
            vehicle.currencyCode = currencyCode
            vehicle.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            VehicleComplianceSync.syncReminders(for: vehicle, in: modelContext)
            try? modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSavedAlert = true
        } else {
            let created = Vehicle(
                name: trimmedName,
                make: make.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                fuelType: fuelType,
                odometerUnit: odometerUnit,
                currencyCode: currencyCode,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                registrationPlate: plate
            )
            modelContext.insert(created)
            if makeActive {
                activeVehicleStore.select(created)
            }
            try? modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }

    private func deleteVehicle() {
        guard let vehicle else { return }
        if activeVehicleStore.activeVehicleID == vehicle.id {
            activeVehicleStore.activeVehicleID = nil
        }
        modelContext.delete(vehicle)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        dismiss()
    }
}
