import SwiftData
import SwiftUI

struct VehicleComplianceCard: View {
    let vehicle: Vehicle

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(vehicle.displayPlate.isEmpty ? "No plate" : vehicle.displayPlate)
                        .font(.title2.weight(.bold))
                        .monospaced()
                    Spacer()
                    if let refreshed = vehicle.lastComplianceRefresh {
                        Text("Updated \(refreshed.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 10) {
                    statusPill(
                        title: "MOT",
                        status: vehicle.motStatus.isEmpty ? "Unknown" : vehicle.motStatus,
                        date: vehicle.motExpiry,
                        ok: vehicle.motIsValid
                    )
                    statusPill(
                        title: "Tax",
                        status: vehicle.taxStatus.isEmpty ? "Unknown" : vehicle.taxStatus,
                        date: vehicle.taxDueDate,
                        ok: vehicle.taxIsValid
                    )
                    statusPill(
                        title: "Insurance",
                        status: vehicle.insuranceProvider.isEmpty ? "Manual" : vehicle.insuranceProvider,
                        date: vehicle.insuranceExpiry,
                        ok: (Vehicle.daysUntil(vehicle.insuranceExpiry) ?? 1) > 0
                    )
                }

                if !vehicle.colour.isEmpty || vehicle.yearOfManufacture > 0 || vehicle.engineCapacityCC > 0 {
                    Text(
                        [
                            vehicle.colour,
                            vehicle.yearOfManufacture > 0 ? "\(vehicle.yearOfManufacture)" : nil,
                            vehicle.engineCapacityCC > 0 ? "\(vehicle.engineCapacityCC) cc" : nil,
                            vehicle.co2Emissions > 0 ? "\(vehicle.co2Emissions) g/km CO₂" : nil,
                        ]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statusPill(title: String, status: String, date: Date?, ok: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ok ? Color.green : Color.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let date {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let days = Vehicle.daysUntil(date) {
                    Text(days >= 0 ? "\(days)d left" : "\(-days)d overdue")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(days < 30 ? Color.orange : .secondary)
                }
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}

struct VehicleComplianceEditor: View {
    @Bindable var vehicle: Vehicle
    @Environment(\.modelContext) private var modelContext
    @AppStorage("dvlaAPIKey") private var dvlaAPIKey = ""

    @State private var isRefreshing = false
    @State private var message: String?
    @State private var useMOTDate = false
    @State private var useTaxDate = false
    @State private var useInsuranceDate = false

    var body: some View {
        Section("UK plate & compliance") {
            TextField("Registration", text: $vehicle.registrationPlate)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            TextField("Colour", text: $vehicle.colour)
            HStack {
                Text("Year")
                Spacer()
                TextField("YYYY", value: $vehicle.yearOfManufacture, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
            }

            LabeledContent("MOT status") {
                TextField("Valid / Not valid", text: $vehicle.motStatus)
                    .multilineTextAlignment(.trailing)
            }
            Toggle("MOT expiry", isOn: $useMOTDate)
            if useMOTDate {
                DatePicker("MOT expiry", selection: Binding(
                    get: { vehicle.motExpiry ?? .now },
                    set: { vehicle.motExpiry = $0 }
                ), displayedComponents: .date)
            }

            LabeledContent("Tax status") {
                TextField("Taxed / SORN", text: $vehicle.taxStatus)
                    .multilineTextAlignment(.trailing)
            }
            Toggle("Tax due date", isOn: $useTaxDate)
            if useTaxDate {
                DatePicker("Tax due", selection: Binding(
                    get: { vehicle.taxDueDate ?? .now },
                    set: { vehicle.taxDueDate = $0 }
                ), displayedComponents: .date)
            }

            TextField("Insurer", text: $vehicle.insuranceProvider)
            Toggle("Insurance expiry", isOn: $useInsuranceDate)
            if useInsuranceDate {
                DatePicker("Insurance expiry", selection: Binding(
                    get: { vehicle.insuranceExpiry ?? .now },
                    set: { vehicle.insuranceExpiry = $0 }
                ), displayedComponents: .date)
            }

            Button {
                Task { await refreshDVLA() }
            } label: {
                if isRefreshing {
                    ProgressView()
                } else {
                    Label("Refresh MOT & tax from DVLA", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .disabled(isRefreshing || vehicle.registrationPlate.isEmpty)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Link("Check MOT history on GOV.UK", destination: URL(string: "https://www.gov.uk/check-mot-history")!)
            Link("Check vehicle tax on GOV.UK", destination: URL(string: "https://www.gov.uk/check-vehicle-tax")!)
            Link("Check insurance (askMID)", destination: URL(string: "https://ownvehicle.askmid.com/")!)
        }
        .onAppear {
            useMOTDate = vehicle.motExpiry != nil
            useTaxDate = vehicle.taxDueDate != nil
            useInsuranceDate = vehicle.insuranceExpiry != nil
        }
        .onChange(of: useMOTDate) { _, on in
            if !on { vehicle.motExpiry = nil }
            else if vehicle.motExpiry == nil { vehicle.motExpiry = Calendar.current.date(byAdding: .year, value: 1, to: .now) }
        }
        .onChange(of: useTaxDate) { _, on in
            if !on { vehicle.taxDueDate = nil }
            else if vehicle.taxDueDate == nil { vehicle.taxDueDate = Calendar.current.date(byAdding: .month, value: 6, to: .now) }
        }
        .onChange(of: useInsuranceDate) { _, on in
            if !on { vehicle.insuranceExpiry = nil }
            else if vehicle.insuranceExpiry == nil { vehicle.insuranceExpiry = Calendar.current.date(byAdding: .year, value: 1, to: .now) }
        }
    }

    @MainActor
    private func refreshDVLA() async {
        isRefreshing = true
        message = nil
        defer { isRefreshing = false }
        do {
            let details = try await DVLAVehicleService.fetch(
                registration: vehicle.registrationPlate,
                apiKey: dvlaAPIKey
            )
            vehicle.applyDVLA(details)
            useMOTDate = vehicle.motExpiry != nil
            useTaxDate = vehicle.taxDueDate != nil
            VehicleComplianceSync.syncReminders(for: vehicle, in: modelContext)
            try? modelContext.save()
            message = "Updated from DVLA. MOT/tax reminders synced."
        } catch {
            message = error.localizedDescription
        }
    }
}
