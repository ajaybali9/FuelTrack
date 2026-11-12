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
    @State private var note = ""

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
            }

            Section("Tank") {
                Toggle("Full tank", isOn: $isFullTank)
                Toggle("Missed fill-up before this", isOn: $skipped)
            }

            Section("Details") {
                TextField("Station", text: $station)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }

            if let liters = parsedLiters, liters > 0, let cost = parsedCost {
                Section("Preview") {
                    LabeledContent("Price / L", value: Formatters.pricePerLiter(cost / liters, code: currencyCode))
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Fill-up" : "New Fill-up")
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
        if let fillUp {
            date = fillUp.date
            odometerText = formatNumber(fillUp.odometer)
            litersText = formatNumber(fillUp.liters)
            totalCostText = formatNumber(fillUp.totalCost)
            currencyCode = fillUp.currencyCode
            isFullTank = fillUp.isFullTank
            skipped = fillUp.skipped
            station = fillUp.station
            note = fillUp.note
        } else {
            currencyCode = vehicle.currencyCode
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
            fillUp.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
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
                vehicle: vehicle
            )
            modelContext.insert(created)
        }

        try? modelContext.save()
        if !isEditing {
            dismiss()
        }
    }
}
