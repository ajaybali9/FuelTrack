import SwiftData
import SwiftUI

struct FillUpListView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @State private var showingAdd = false

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    private var fillUps: [FillUp] {
        activeVehicle?.sortedFillUps.reversed() ?? []
    }

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    }

    private var monthSpend: Double {
        fillUps.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.totalCost }
    }

    private var monthLiters: Double {
        fillUps.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.liters }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    ContentUnavailableView(
                        "Add a vehicle first",
                        systemImage: "car.side",
                        description: Text("Fill-ups are logged per vehicle. Add one from More → Vehicles.")
                    )
                } else if activeVehicle == nil {
                    ContentUnavailableView(
                        "Select a vehicle",
                        systemImage: "car.side",
                        description: Text("Pick an active vehicle from the toolbar to log fill-ups.")
                    )
                } else if fillUps.isEmpty, let vehicle = activeVehicle {
                    ContentUnavailableView {
                        Label("No fill-ups yet", systemImage: "fuelpump")
                    } description: {
                        Text("Log your first fill-up for \(vehicle.name).")
                    } actions: {
                        Button("Log fill-up") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                            .tint(GlassTheme.accent)
                    }
                } else if let vehicle = activeVehicle {
                    ScrollView {
                        let economyByFillID: [UUID: ConsumptionSegment] = {
                            let snapshots = fillUps.map {
                                FillUpSnapshot(
                                    id: $0.id,
                                    date: $0.date,
                                    odometer: $0.odometer,
                                    liters: $0.liters,
                                    totalCost: $0.totalCost,
                                    isFullTank: $0.isFullTank,
                                    skipped: $0.skipped
                                )
                            }
                            return FuelStats.segmentsByEndingFillUpID(from: snapshots)
                        }()

                        VStack(spacing: 16) {
                            summary(for: vehicle)
                                .staggeredAppear(index: 0)

                            InstrumentSectionHeader(title: "Fill-up log", tint: GlassTheme.accent)
                                .staggeredAppear(index: 1)

                            LazyVStack(spacing: 12) {
                                ForEach(Array(fillUps.enumerated()), id: \.element.id) { index, fillUp in
                                    NavigationLink {
                                        FillUpFormView(vehicle: vehicle, fillUp: fillUp)
                                    } label: {
                                        FillUpCard(
                                            fillUp: fillUp,
                                            unit: vehicle.odometerUnit,
                                            segment: economyByFillID[fillUp.id]
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .staggeredAppear(index: min(index + 2, 12))
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            modelContext.delete(fillUp)
                                            try? modelContext.save()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Fuel Log")
            .fuelTrackScreen()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !vehicles.isEmpty {
                        Menu {
                            ForEach(vehicles) { vehicle in
                                Button {
                                    activeVehicleStore.select(vehicle)
                                } label: {
                                    if vehicle.id == activeVehicle?.id {
                                        Label(vehicle.name, systemImage: "checkmark")
                                    } else {
                                        Text(vehicle.name)
                                    }
                                }
                            }
                        } label: {
                            Label(activeVehicle?.name ?? "Vehicle", systemImage: "car.side")
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let vehicle = activeVehicle {
                        NavigationLink {
                            FillUpMapView(vehicle: vehicle)
                        } label: {
                            Image(systemName: "map")
                        }
                        .accessibilityLabel("Fill-up map")
                    }
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(activeVehicle == nil)
                }
            }
            .sheet(isPresented: $showingAdd) {
                if let vehicle = activeVehicle {
                    NavigationStack {
                        FillUpFormView(vehicle: vehicle, fillUp: nil)
                    }
                }
            }
        }
    }

    private func summary(for vehicle: Vehicle) -> some View {
        VStack(spacing: 12) {
            GlassCard(padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    InstrumentSectionHeader(title: vehicle.name, tint: GlassTheme.accentWarm)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("THIS MONTH")
                                .font(FuelTrackTokens.labelFont())
                                .tracking(0.06)
                                .foregroundStyle(.secondary)
                            Text(Formatters.currency(monthSpend, code: vehicle.currencyCode))
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .foregroundStyle(GlassTheme.accentWarm)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .contentTransition(.numericText())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(Formatters.liters(monthLiters))
                                .font(FuelTrackTokens.numericFont(size: .title3))
                                .foregroundStyle(GlassTheme.accent)
                            Text("\(fillUps.filter { $0.date >= monthStart }.count) fills")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    LinearGradient(
                        colors: [GlassTheme.accentWarm, GlassTheme.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 3)
                    .clipShape(Capsule())
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                GlassStatChip(
                    title: "Fill-ups",
                    value: "\(fillUps.count)"
                )
                if let last = fillUps.first {
                    GlassStatChip(
                        title: "Last fill",
                        value: Formatters.shortDate(last.date),
                        tint: GlassTheme.accentWarm
                    )
                }
            }
        }
    }
}

private struct FillUpCard: View {
    let fillUp: FillUp
    let unit: OdometerUnit
    let segment: ConsumptionSegment?

    var body: some View {
        InstrumentListRow(tint: GlassTheme.accentWarm) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Formatters.shortDate(fillUp.date))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if !fillUp.station.isEmpty {
                            Text(fillUp.station)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } else {
                            Text(fillUp.fuelType.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(Formatters.currency(fillUp.totalCost, code: fillUp.currencyCode))
                        .font(FuelTrackTokens.numericFont(size: .title3))
                        .foregroundStyle(GlassTheme.accentWarm)
                }

                HStack(spacing: 16) {
                    metric(Formatters.liters(fillUp.liters), label: "Volume", tint: GlassTheme.accent)
                    metric(Formatters.odometer(fillUp.odometer, unit: unit), label: "Odo", tint: GlassTheme.accent)
                    if let ppl = fillUp.pricePerLiter {
                        metric(Formatters.pricePerLiter(ppl, code: fillUp.currencyCode), label: "Per litre", tint: GlassTheme.accentWarm)
                    }
                }

                if let segment {
                    HStack(spacing: 16) {
                        metric(
                            Formatters.consumptionMPG(segment.mpg(unit: unit)),
                            label: "MPG",
                            tint: GlassTheme.accentWarm
                        )
                        metric(
                            Formatters.costPerDistance(
                                segment.costPerDistance(unit: unit),
                                unit: unit,
                                code: fillUp.currencyCode
                            ),
                            label: unit == .miles ? "Per mi" : "Per km",
                            tint: GlassTheme.accentWarm
                        )
                    }
                }

                HStack(spacing: 8) {
                    Text(fillUp.fuelType.shortName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(GlassTheme.accent))
                    Text(fillUp.isFullTank ? "Full tank" : "Partial")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(fillUp.isFullTank ? GlassTheme.success : GlassTheme.warning)
                    if fillUp.skipped {
                        Text("Missed prior")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(GlassTheme.error)
                    }
                    Spacer()
                }
            }
        }
    }

    private func metric(_ value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.05)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(FuelTrackTokens.numericFont(size: .subheadline))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
