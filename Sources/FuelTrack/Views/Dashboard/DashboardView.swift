import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    ContentUnavailableView(
                        "Add a vehicle",
                        systemImage: "car.side",
                        description: Text("Create your first car to start logging fill-ups.")
                    )
                } else if let vehicle = activeVehicle {
                    vehicleDashboard(vehicle)
                } else {
                    ContentUnavailableView(
                        "Select a vehicle",
                        systemImage: "car.side",
                        description: Text("Pick an active vehicle from the Vehicles tab.")
                    )
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                if !vehicles.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
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
            }
        }
    }

    @ViewBuilder
    private func vehicleDashboard(_ vehicle: Vehicle) -> some View {
        let stats = FuelStats.compute(vehicle: vehicle)
        let unit = vehicle.odometerUnit
        let currency = vehicle.currencyCode

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vehicle.name)
                        .font(.title2.weight(.semibold))
                    Text(vehicle.displaySubtitle)
                        .foregroundStyle(.secondary)
                    if let odo = vehicle.latestOdometer {
                        Text("Odometer \(Formatters.odometer(odo, unit: unit))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Consumption") {
                statRow("Average", Formatters.consumptionL100(stats.averageLitersPer100km))
                statRow("Average MPG", Formatters.consumptionMPG(stats.averageMPG))
                if let last = stats.lastSegment {
                    statRow(
                        "Last tank",
                        Formatters.consumptionL100(last.litersPer100km(unit: unit))
                    )
                    statRow(
                        "Last tank MPG",
                        Formatters.consumptionMPG(last.mpg(unit: unit))
                    )
                } else {
                    Text("Log two full tanks to see consumption.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Costs") {
                statRow("This month", Formatters.currency(stats.spendThisMonth, code: currency))
                statRow("All time", Formatters.currency(stats.totalSpend, code: currency))
                statRow(
                    "Avg price",
                    Formatters.pricePerLiter(stats.averagePricePerLiter, code: currency)
                )
                statRow(
                    "Cost / distance",
                    Formatters.costPerDistance(stats.averageCostPerDistance, unit: unit, code: currency)
                )
            }

            Section("Totals") {
                statRow("Fill-ups", "\(stats.fillUpCount)")
                statRow("Fuel", Formatters.liters(stats.totalLiters))
                statRow("Distance", Formatters.odometer(stats.totalDistance, unit: unit))
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
