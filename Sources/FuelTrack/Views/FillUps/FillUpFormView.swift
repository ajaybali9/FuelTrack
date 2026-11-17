import SwiftData
import SwiftUI

struct FillUpFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle
    var fillUp: FillUp?

    @State private var date = Date.now
    @State private var odometerText = ""
    @State private var litersText = ""
    @State private var totalCostText = ""
    @State private var currencyCode: CurrencyCode = .gbp
    @State private var isFullTank = true
    @State private var skipped = false
    @State private var station = ""
    @State private var stationExternalId = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var note = ""
    @State private var fuelType: FuelType = .petrolE10
    @State private var showingStationPicker = false
    @State private var selectedPricePence: Double?
    @State private var saveError: String?

    private var isEditing: Bool { fillUp != nil }

    private var parsedOdometer: Double? { Double(odometerText.replacingOccurrences(of: ",", with: ".")) }
    private var parsedLiters: Double? { Double(litersText.replacingOccurrences(of: ",", with: ".")) }
    private var parsedCost: Double? { Double(totalCostText.replacingOccurrences(of: ",", with: ".")) }

    private var canSave: Bool {
        guard let odo = parsedOdometer, odo >= 0,
              let liters = parsedLiters, liters > 0,
              let cost = parsedCost, cost >= 0 else {
            return false
        }
        return true
    }

    var body: some View {
        Form {
            Section("Fill-up") {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                HStack {
                    Text("Odometer (\(vehicle.odometerUnit.shortLabel))")
                    Spacer()
                    TextField("0", text: $odometerText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                HStack {
                    Text("Volume (L)")
                    Spacer()
                    TextField("0.00", text: $litersText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                HStack {
                    Text("Total cost")
                    Spacer()
                    TextField("0.00", text: $totalCostText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                Picker("Currency", selection: $currencyCode) {
                    ForEach(CurrencyCode.allCases) { code in
                        Text(code.displayName).tag(code)
                    }
                }
                Picker("Fuel type", selection: $fuelType) {
                    ForEach(FuelType.selectableCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            Section("Tank") {
                Toggle("Full tank", isOn: $isFullTank)
                Toggle("Missed fill-up before this", isOn: $skipped)
            }

            Section("Details") {
                HStack {
                    TextField("Station", text: $station)
                    Button {
                        showingStationPicker = true
                    } label: {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(GlassTheme.accent)
                    }
                    .accessibilityLabel("Choose station from list")
                }
                if let selectedPricePence {
                    Text(String(format: "Listed at %.1fp/L", selectedPricePence))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let liters = parsedLiters, liters > 0, currencyCode == .gbp {
                        Button("Fill total from station price") {
                            totalCostText = String(format: "%.2f", (selectedPricePence / 100.0) * liters)
                        }
                    }
                }
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }

            if let liters = parsedLiters, liters > 0, let cost = parsedCost {
                Section("Preview") {
                    LabeledContent("Price / L", value: Formatters.pricePerLiter(cost / liters, code: currencyCode))
                }
            }

            if let saveError {
                Section {
                    Text(saveError).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit fill-up" : "New fill-up")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackForm()
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
        .sheet(isPresented: $showingStationPicker) {
            StationPickerView(
                fuelType: fuelType,
                onSelect: { picked in
                    applyStation(picked)
                },
                onSelectName: { name in
                    station = name
                    stationExternalId = ""
                    latitude = nil
                    longitude = nil
                    selectedPricePence = nil
                }
            )
        }
        .onAppear(perform: load)
    }

    private func applyStation(_ picked: NearbyStation) {
        // Synthetic used-station picks have a zero coordinate and "used-" id.
        if picked.id.hasPrefix("used-") {
            station = picked.name
            stationExternalId = ""
            latitude = nil
            longitude = nil
            selectedPricePence = nil
            return
        }

        var parts: [String] = []
        if !picked.brand.isEmpty, !picked.name.localizedCaseInsensitiveContains(picked.brand) {
            parts.append(picked.brand)
        }
        parts.append(picked.name)
        if !picked.city.isEmpty, !picked.name.localizedCaseInsensitiveContains(picked.city) {
            parts.append(picked.city)
        }
        if !picked.postcode.isEmpty {
            parts.append(picked.postcode)
        }
        station = parts.joined(separator: " · ")
        stationExternalId = picked.id
        latitude = picked.coordinate.latitude
        longitude = picked.coordinate.longitude
        selectedPricePence = picked.pricePence
        if let pence = picked.pricePence,
           let liters = parsedLiters,
           liters > 0,
           currencyCode == .gbp,
           (parsedCost ?? 0) <= 0 {
            totalCostText = String(format: "%.2f", (pence / 100.0) * liters)
        }
    }

    private func load() {
        if let fillUp {
            date = fillUp.date
            odometerText = formatNumber(fillUp.odometer)
            litersText = formatNumber(fillUp.liters)
            totalCostText = formatNumber(fillUp.totalCost)
            currencyCode = fillUp.currencyCode
            isFullTank = fillUp.isFullTank
            skipped = fillUp.skipped
            station = fillUp.station
            stationExternalId = fillUp.stationExternalId
            latitude = fillUp.latitude
            longitude = fillUp.longitude
            note = fillUp.note
            fuelType = fillUp.fuelType
        } else {
            currencyCode = vehicle.currencyCode
            fuelType = vehicle.fuelType
            if let last = vehicle.latestOdometer {
                odometerText = formatNumber(last)
            }
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func save() {
        guard let odo = parsedOdometer,
              let liters = parsedLiters,
              let cost = parsedCost else { return }

        if let fillUp {
            fillUp.date = date
            fillUp.odometer = odo
            fillUp.liters = liters
            fillUp.totalCost = cost
            fillUp.currencyCode = currencyCode
            fillUp.isFullTank = isFullTank
            fillUp.skipped = skipped
            fillUp.station = station.trimmingCharacters(in: .whitespacesAndNewlines)
            fillUp.stationExternalId = stationExternalId
            fillUp.latitude = latitude
            fillUp.longitude = longitude
            fillUp.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            fillUp.fuelType = fuelType
        } else {
            let created = FillUp(
                date: date,
                odometer: odo,
                liters: liters,
                totalCost: cost,
                currencyCode: currencyCode,
                isFullTank: isFullTank,
                skipped: skipped,
                station: station.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                fuelType: fuelType,
                latitude: latitude,
                longitude: longitude,
                stationExternalId: stationExternalId,
                vehicle: vehicle
            )
            modelContext.insert(created)
        }

        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            saveError = nil
            dismiss()
        } catch {
            saveError = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
