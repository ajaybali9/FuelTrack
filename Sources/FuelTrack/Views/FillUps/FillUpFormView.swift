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
    @State private var attemptedSave = false

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

    private var pricePerLiterLabel: String? {
        guard let liters = parsedLiters, liters > 0, let cost = parsedCost else { return nil }
        return Formatters.pricePerLiter(cost / liters, code: currencyCode)
    }

    private var odometerInvalid: Bool {
        attemptedSave && (parsedOdometer == nil || (parsedOdometer ?? -1) < 0)
    }

    private var litersInvalid: Bool {
        attemptedSave && (parsedLiters == nil || (parsedLiters ?? 0) <= 0)
    }

    private var costInvalid: Bool {
        attemptedSave && (parsedCost == nil || (parsedCost ?? -1) < 0)
    }

    var body: some View {
        GlassFormScaffold {
            GlassFormSection(title: "Fill-up", index: 0) {
                VStack(spacing: 14) {
                    FTDateField(label: "Date", date: $date, components: [.date, .hourAndMinute])
                    FTNumericField(
                        label: "Odometer",
                        text: $odometerText,
                        unit: vehicle.odometerUnit.shortLabel,
                        isInvalid: odometerInvalid
                    )
                    FTNumericField(
                        label: "Volume",
                        text: $litersText,
                        unit: "L",
                        prompt: "0.00",
                        isInvalid: litersInvalid
                    )
                    FTNumericField(
                        label: "Total cost",
                        text: $totalCostText,
                        unit: currencyCode.symbol,
                        prompt: "0.00",
                        isInvalid: costInvalid,
                        tint: GlassTheme.accentWarm
                    )
                    FTChipPicker(
                        label: "Currency",
                        selection: $currencyCode,
                        options: Array(CurrencyCode.allCases),
                        tint: GlassTheme.accentWarm,
                        shortLabel: { $0.symbol + " " + $0.rawValue }
                    )
                    FTChipPicker(
                        label: "Fuel type",
                        selection: $fuelType,
                        options: FuelType.selectableCases,
                        shortLabel: { $0.shortName }
                    )
                }
            }

            GlassFormSection(title: "Tank", index: 1) {
                VStack(spacing: 12) {
                    FTToggleRow(
                        label: "Full tank",
                        isOn: $isFullTank,
                        caption: "Needed for full-tank economy"
                    )
                    FTToggleRow(
                        label: "Missed fill-up before this",
                        isOn: $skipped,
                        caption: "Breaks economy chain intentionally"
                    )
                }
            }

            GlassFormSection(title: "Details", index: 2) {
                VStack(spacing: 14) {
                    FTStationField(
                        station: $station,
                        pricePence: selectedPricePence,
                        currencyCode: currencyCode,
                        litersText: litersText,
                        onPickStation: { showingStationPicker = true },
                        onFillFromPrice: {
                            guard let pence = selectedPricePence,
                                  let liters = parsedLiters,
                                  liters > 0 else { return }
                            totalCostText = String(format: "%.2f", (pence / 100.0) * liters)
                        }
                    )
                    FTTextArea(label: "Note", text: $note, lineLimit: 2...4)
                }
            }

            if let saveError {
                GlassFormSection(title: nil, index: 3) {
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(GlassTheme.error)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            FTLiveMetricsStrip(pricePerLiter: pricePerLiterLabel)
        }
        .animation(.smooth(duration: 0.28), value: pricePerLiterLabel)
        .navigationTitle(isEditing ? "Edit fill-up" : "New fill-up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    attemptedSave = true
                    save()
                }
                .disabled(!canSave)
                .fontWeight(.semibold)
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
