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
                } else {
                    List {
                        ForEach(fillUps) { fillUp in
                            NavigationLink {
                                FillUpFormView(vehicle: activeVehicle!, fillUp: fillUp)
                            } label: {
                                FillUpRow(fillUp: fillUp, unit: activeVehicle?.odometerUnit ?? .miles)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Fill-ups")
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

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(fillUps[index])
        }
        try? modelContext.save()
    }
}

private struct FillUpRow: View {
    let fillUp: FillUp
    let unit: OdometerUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Formatters.shortDate(fillUp.date))
                    .font(.headline)
                Spacer()
                Text(Formatters.currency(fillUp.totalCost, code: fillUp.currencyCode))
                    .font(.headline)
            }
            HStack {
                Text(Formatters.liters(fillUp.liters))
                Text("·")
                Text(Formatters.odometer(fillUp.odometer, unit: unit))
                if let ppl = fillUp.pricePerLiter {
                    Text("·")
                    Text(Formatters.pricePerLiter(ppl, code: fillUp.currencyCode))
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if fillUp.isFullTank {
                    Label("Full", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else {
                    Label("Partial", systemImage: "circle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if fillUp.skipped {
                    Label("Missed", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                if !fillUp.station.isEmpty {
                    Text(fillUp.station)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
