import SwiftData
import SwiftUI

struct CarCostListContent: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(sort: \CustomExpenseCategory.createdAt) private var customs: [CustomExpenseCategory]
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @AppStorage("spendPeriod") private var spendPeriodRaw = SpendPeriod.monthly.rawValue
    @State private var filterKey: String?

    private var period: Binding<SpendPeriod> {
        Binding(
            get: { SpendPeriod(rawValue: spendPeriodRaw) ?? .monthly },
            set: { spendPeriodRaw = $0.rawValue }
        )
    }

    private var selectedPeriod: SpendPeriod {
        SpendPeriod(rawValue: spendPeriodRaw) ?? .monthly
    }

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    private var costs: [CarCost] {
        activeVehicle?.sortedCosts ?? []
    }

    private var periodStart: Date {
        selectedPeriod.startDate()
    }

    private var periodCosts: [CarCost] {
        costs.filter { $0.date >= periodStart }
    }

    private var filteredCosts: [CarCost] {
        let base = periodCosts
        guard let filterKey else { return base }
        return base.filter { $0.categoryKey == filterKey }
    }

    private var periodTotal: Double {
        periodCosts.reduce(0) { $0 + $1.amount }
    }

    private var categoryRows: [CategorySpendRow] {
        let keys = Set(costs.map(\.categoryKey))
        return keys.compactMap { key -> CategorySpendRow? in
            let items = costs.filter { $0.categoryKey == key }
            let periodItems = items.filter { $0.date >= periodStart }
            let periodSum = periodItems.reduce(0) { $0 + $1.amount }
            guard periodSum > 0 else { return nil }
            let all = items.reduce(0) { $0 + $1.amount }
            let category = SpendCategoryCatalog.resolve(key: key, scope: .car, customs: customs)
            return CategorySpendRow(
                id: key,
                category: category,
                periodTotal: periodSum,
                allTimeTotal: all,
                entryCount: periodItems.count
            )
        }
        .sorted { $0.periodTotal > $1.periodTotal }
    }

    var body: some View {
        Group {
            if vehicles.isEmpty {
                ContentUnavailableView(
                    "Add a vehicle first",
                    systemImage: "car.side",
                    description: Text("Car spend is tracked per vehicle. Add one from More → Vehicles.")
                )
            } else if activeVehicle == nil {
                ContentUnavailableView(
                    "Select a vehicle",
                    systemImage: "car.side",
                    description: Text("Pick an active vehicle from the toolbar to track car spend.")
                )
            } else if costs.isEmpty {
                ContentUnavailableView(
                    "No car costs yet",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Track service, MOT, road tax, insurance and more for \(activeVehicle?.name ?? "this car").")
                )
            } else if let vehicle = activeVehicle {
                ScrollView {
                    VStack(spacing: 14) {
                        SpendTotalsCard(
                            periodTotal: periodTotal,
                            allTimeTotal: vehicle.costsAllTime,
                            yearTotal: vehicle.costsThisYear,
                            currency: vehicle.currencyCode,
                            periodEntryCount: periodCosts.count,
                            subtitle: vehicle.name,
                            period: period
                        )

                        CategorySpendBreakdownCard(
                            rows: categoryRows,
                            currency: vehicle.currencyCode,
                            period: selectedPeriod,
                            selectedKey: filterKey,
                            onSelect: { filterKey = $0 }
                        )

                        LazyVStack(spacing: 12) {
                            ForEach(filteredCosts) { cost in
                                NavigationLink {
                                    CostFormView(vehicle: vehicle, cost: cost)
                                } label: {
                                    costRow(cost, currency: vehicle.currencyCode)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        modelContext.delete(cost)
                                        try? modelContext.save()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func costRow(_ cost: CarCost, currency: CurrencyCode) -> some View {
        let resolved = SpendCategoryCatalog.resolve(key: cost.categoryKey, scope: .car, customs: customs)
        return GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: resolved.systemImage)
                    .font(.title3)
                    .foregroundStyle(GlassTheme.accent)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: .circle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(cost.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(resolved.name) · \(Formatters.shortDate(cost.date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !cost.note.isEmpty {
                        Text(cost.note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(Formatters.currency(cost.amount, code: cost.currencyCode))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct CostFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomExpenseCategory.createdAt) private var customs: [CustomExpenseCategory]

    let vehicle: Vehicle
    var cost: CarCost?

    @State private var title = ""
    @State private var date = Date.now
    @State private var amountText = ""
    @State private var odometerText = ""
    @State private var categoryKey = CostCategory.service.rawValue
    @State private var currencyCode: CurrencyCode = .gbp
    @State private var note = ""
    @State private var showingSavedAlert = false
    @State private var showingCategories = false
    @State private var saveError: String?

    private var isEditing: Bool { cost != nil }
    private var parsedAmount: Double? { Double(amountText.replacingOccurrences(of: ",", with: ".")) }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (parsedAmount ?? -1) >= 0
    }

    private var categoryOptions: [ResolvedSpendCategory] {
        SpendCategoryCatalog.all(scope: .car, customs: customs)
    }

    var body: some View {
        Form {
            Section("Cost") {
                TextField("Title", text: $title)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Category", selection: $categoryKey) {
                    ForEach(categoryOptions) { item in
                        Label(item.name, systemImage: item.systemImage).tag(item.id)
                    }
                }
                Button("Manage categories") { showingCategories = true }
                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                Picker("Currency", selection: $currencyCode) {
                    ForEach(CurrencyCode.allCases) { code in
                        Text(code.displayName).tag(code)
                    }
                }
                HStack {
                    Text("Odometer (optional)")
                    Spacer()
                    TextField("—", text: $odometerText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
            }
            Section("Notes") {
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(2...5)
            }
            if let saveError {
                Section {
                    Text(saveError).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit cost" : "New cost")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackForm()
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(!canSave)
            }
        }
        .sheet(isPresented: $showingCategories) {
            NavigationStack {
                CustomCategoriesView(scope: .car)
            }
        }
        .alert("Cost saved", isPresented: $showingSavedAlert) {
            Button("OK") {
                if !isEditing { dismiss() }
            }
        } message: {
            Text(isEditing ? "Your changes are saved." : "Added to \(vehicle.name).")
        }
        .onAppear(perform: load)
    }

    private func load() {
        if let cost {
            title = cost.title
            date = cost.date
            amountText = String(format: "%.2f", cost.amount)
            odometerText = cost.odometer.map { String(format: "%.0f", $0) } ?? ""
            categoryKey = cost.categoryKey
            currencyCode = cost.currencyCode
            note = cost.note
        } else {
            currencyCode = vehicle.currencyCode
            if let odo = vehicle.latestOdometer {
                odometerText = String(format: "%.0f", odo)
            }
        }
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let odo = Double(odometerText.replacingOccurrences(of: ",", with: "."))
        if let cost {
            cost.title = trimmed
            cost.date = date
            cost.amount = amount
            cost.odometer = odo
            cost.categoryKey = categoryKey
            cost.currencyCode = currencyCode
            cost.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            modelContext.insert(
                CarCost(
                    title: trimmed,
                    date: date,
                    odometer: odo,
                    amount: amount,
                    currencyCode: currencyCode,
                    categoryKey: categoryKey,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                    vehicle: vehicle
                )
            )
        }
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showingSavedAlert = true
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}
