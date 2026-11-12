import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct FuelioImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue

    @State private var showingPicker = false
    @State private var currencyCode: CurrencyCode = .gbp
    @State private var setActive = true
    @State private var isImporting = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text("In Fuelio, open Settings → Export CSV (or Backup → Export CSV) for a vehicle, then pick that file here. FuelTrack imports the vehicle and fill-up log.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Import options") {
                Picker("Currency for imported costs", selection: $currencyCode) {
                    ForEach(CurrencyCode.allCases) { code in
                        Text(code.displayName).tag(code)
                    }
                }
                Toggle("Set imported vehicle as active", isOn: $setActive)
            }

            Section {
                Button {
                    showingPicker = true
                } label: {
                    if isImporting {
                        ProgressView()
                    } else {
                        Label("Choose Fuelio CSV…", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(isImporting)
            }

            if let statusMessage {
                Section("Result") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Import from Fuelio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            currencyCode = CurrencyCode(rawValue: defaultCurrencyCode) ?? .gbp
        }
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importFile(at: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
        }
    }

    private func importFile(at url: URL) {
        isImporting = true
        errorMessage = nil
        statusMessage = nil
        defer { isImporting = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let parsed = try FuelioCSVImporter.parse(data: data, defaultCurrency: currencyCode)

            let vehicle = Vehicle(
                name: parsed.vehicleName,
                make: parsed.make,
                model: parsed.model,
                fuelType: parsed.fuelType,
                odometerUnit: parsed.odometerUnit,
                currencyCode: currencyCode,
                notes: parsed.notes,
                registrationPlate: parsed.registrationPlate
            )
            modelContext.insert(vehicle)

            for fill in parsed.fillUps {
                let created = FillUp(
                    date: fill.date,
                    odometer: fill.odometer,
                    liters: fill.liters,
                    totalCost: fill.totalCost,
                    currencyCode: currencyCode,
                    isFullTank: fill.isFullTank,
                    skipped: fill.skipped,
                    station: fill.station,
                    note: fill.note,
                    vehicle: vehicle
                )
                modelContext.insert(created)
            }

            try modelContext.save()

            if setActive {
                activeVehicleStore.select(vehicle)
            }

            var message = "Imported “\(parsed.vehicleName)” with \(parsed.fillUps.count) fill-up"
            if parsed.fillUps.count != 1 { message += "s" }
            message += "."
            if parsed.skippedRows > 0 {
                message += " Skipped \(parsed.skippedRows) invalid row"
                if parsed.skippedRows != 1 { message += "s" }
                message += "."
            }
            statusMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
