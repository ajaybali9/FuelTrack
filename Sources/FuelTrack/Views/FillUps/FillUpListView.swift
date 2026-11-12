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
                        description: Text("Fill-ups are logged per vehicle.")
                    )
                } else if fillUps.isEmpty {
                    ContentUnavailableView(
                        "No fill-ups yet",
                        systemImage: "fuelpump",
                        description: Text("Log your first fill-up for \(activeVehicle?.name ?? "this car").")
                    )
                } else if let vehicle = activeVehicle {
                    ScrollView {
                        VStack(spacing: 14) {
                            summary(for: vehicle)

                            LazyVStack(spacing: 12) {
                                ForEach(fillUps) { fillUp in
                                    NavigationLink {
                                        FillUpFormView(vehicle: vehicle, fillUp: fillUp)
                                    } label: {
                                        FillUpCard(
                                            fillUp: fillUp,
                                            unit: vehicle.odometerUnit
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            modelContext.delete(fillUp)
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
            .navigationTitle("Fuel")
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
                ToolbarItem(placement: .topBarTrailing) {
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
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(vehicle.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Formatters.currency(monthSpend, code: vehicle.currencyCode))
                                .font(.largeTitle.weight(.bold))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(Formatters.liters(monthLiters))
                                .font(.title3.weight(.semibold))
                            Text("\(fillUps.filter { $0.date >= monthStart }.count) fills")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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

    var body: some View {
        GlassCard {
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
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 16) {
                    metric(Formatters.liters(fillUp.liters), label: "Volume")
                    metric(Formatters.odometer(fillUp.odometer, unit: unit), label: "Odo")
                    if let ppl = fillUp.pricePerLiter {
                        metric(Formatters.pricePerLiter(ppl, code: fillUp.currencyCode), label: "Per litre")
                    }
                }

                HStack(spacing: 8) {
                    Text(fillUp.fuelType.shortName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    Text(fillUp.isFullTank ? "Full tank" : "Partial")
                        .font(.caption)
                        .foregroundStyle(fillUp.isFullTank ? Color.green : Color.orange)
                    if fillUp.skipped {
                        Text("Missed prior")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
            }
        }
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
