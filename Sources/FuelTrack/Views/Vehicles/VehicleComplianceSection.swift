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
                .foregroundStyle(ok ? GlassTheme.success : GlassTheme.warning)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let date {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let days = Vehicle.daysUntil(date) {
                    Text(days >= 0 ? "\(days)d left" : "\(-days)d overdue")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(days < 30 ? GlassTheme.warning : .secondary)
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
    var sectionIndex: Int = 2
    @Environment(\.modelContext) private var modelContext
    @AppStorage("dvlaAPIKey") private var dvlaAPIKey = ""
    @AppStorage("dvlaEnvironment") private var dvlaEnvironmentRaw = DVLAEnvironment.production.rawValue

    @State private var isRefreshing = false
    @State private var message: String?
    @State private var useMOTDate = false
    @State private var useTaxDate = false
    @State private var useInsuranceDate = false

    private var yearBinding: Binding<String> {
        Binding(
            get: {
                vehicle.yearOfManufacture > 0 ? String(vehicle.yearOfManufacture) : ""
            },
            set: { vehicle.yearOfManufacture = Int($0) ?? 0 }
        )
    }

    var body: some View {
        GlassFormSection(title: "UK plate & compliance", index: sectionIndex) {
            VStack(spacing: 14) {
                FTComplianceRail(
                    motStatus: vehicle.motStatus.isEmpty ? "Unknown" : vehicle.motStatus,
                    motOK: vehicle.motIsValid,
                    taxStatus: vehicle.taxStatus.isEmpty ? "Unknown" : vehicle.taxStatus,
                    taxOK: vehicle.taxIsValid,
                    insuranceStatus: vehicle.insuranceProvider.isEmpty ? "Manual" : vehicle.insuranceProvider,
                    insuranceOK: (Vehicle.daysUntil(vehicle.insuranceExpiry) ?? 1) > 0,
                    isRefreshing: isRefreshing,
                    canRefresh: !vehicle.registrationPlate.isEmpty,
                    message: message,
                    onRefresh: { Task { await refreshDVLA() } }
                )

                FTTextField(label: "Colour", text: $vehicle.colour, prompt: "Colour")
                FTTextField(
                    label: "Year",
                    text: yearBinding,
                    prompt: "YYYY",
                    disableAutocorrection: true,
                    keyboard: .numberPad
                )

                FTTextField(
                    label: "MOT status",
                    text: $vehicle.motStatus,
                    prompt: "Valid / Not valid"
                )
                FTOptionalDateField(
                    label: "MOT expiry",
                    enabled: $useMOTDate,
                    date: Binding(
                        get: { vehicle.motExpiry ?? .now },
                        set: { vehicle.motExpiry = $0 }
                    )
                )

                FTTextField(
                    label: "Tax status",
                    text: $vehicle.taxStatus,
                    prompt: "Taxed / SORN"
                )
                FTOptionalDateField(
                    label: "Tax due date",
                    enabled: $useTaxDate,
                    date: Binding(
                        get: { vehicle.taxDueDate ?? .now },
                        set: { vehicle.taxDueDate = $0 }
                    )
                )

                FTTextField(label: "Insurer", text: $vehicle.insuranceProvider, prompt: "Insurer")
                FTOptionalDateField(
                    label: "Insurance expiry",
                    enabled: $useInsuranceDate,
                    date: Binding(
                        get: { vehicle.insuranceExpiry ?? .now },
                        set: { vehicle.insuranceExpiry = $0 }
                    )
                )

                VStack(alignment: .leading, spacing: 8) {
                    Link("Check MOT history on GOV.UK", destination: URL(string: "https://www.gov.uk/check-mot-history")!)
                    Link("Check vehicle tax on GOV.UK", destination: URL(string: "https://www.gov.uk/check-vehicle-tax")!)
                    Link("Check insurance (askMID)", destination: URL(string: "https://ownvehicle.askmid.com/")!)
                }
                .font(.subheadline)
            }
        }
        .onAppear {
            useMOTDate = vehicle.motExpiry != nil
            useTaxDate = vehicle.taxDueDate != nil
            useInsuranceDate = vehicle.insuranceExpiry != nil
            let reviewedKey = "dvlaEnvironmentReviewed"
            guard !UserDefaults.standard.bool(forKey: reviewedKey) else { return }
            dvlaEnvironmentRaw = DVLAEnvironment.production.rawValue
            UserDefaults.standard.set(true, forKey: reviewedKey)
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
            let environment = DVLAEnvironment(rawValue: dvlaEnvironmentRaw) ?? .production
            let details = try await DVLAVehicleService.fetch(
                registration: vehicle.registrationPlate,
                apiKey: dvlaAPIKey,
                environment: environment
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