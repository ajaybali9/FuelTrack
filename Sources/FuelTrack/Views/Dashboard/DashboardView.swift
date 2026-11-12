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
                        description: Text("Pick an active vehicle from More → Vehicles.")
                    )
                }
            }
            .navigationTitle("Home")
            .fuelTrackScreen()
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

        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(vehicle.name)
                            .font(.largeTitle.weight(.bold))
                        Text(vehicle.displaySubtitle)
                            .foregroundStyle(.secondary)
                        if let odo = vehicle.latestOdometer {
                            Text("Odometer \(Formatters.odometer(odo, unit: unit))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !vehicle.registrationPlate.isEmpty || vehicle.motExpiry != nil || vehicle.taxDueDate != nil || vehicle.insuranceExpiry != nil {
                    VehicleComplianceCard(vehicle: vehicle)
                }

                HomeFuelQuickAccess(vehicle: vehicle)

                HomeCarSpendCard(vehicle: vehicle)

                HomePersonalSpendCard()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    GlassStatChip(title: "Avg L/100km", value: Formatters.consumptionL100(stats.averageLitersPer100km))
                    GlassStatChip(title: "Avg MPG", value: Formatters.consumptionMPG(stats.averageMPG), tint: GlassTheme.accentWarm)
                    GlassStatChip(title: "Fuel month", value: Formatters.currency(stats.spendThisMonth, code: currency))
                    GlassStatChip(title: "Car month", value: Formatters.currency(vehicle.costsThisMonth, code: currency), tint: GlassTheme.accentWarm)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Fuel economy")
                            .font(.headline)
                        if let last = stats.lastSegment {
                            row("Last tank", Formatters.consumptionL100(last.litersPer100km(unit: unit)))
                            row("Last tank MPG", Formatters.consumptionMPG(last.mpg(unit: unit)))
                        } else {
                            Text("Log two full tanks to see consumption.")
                                .foregroundStyle(.secondary)
                        }
                        row("Avg price", Formatters.pricePerLiter(stats.averagePricePerLiter, code: currency))
                        row("Cost / distance", Formatters.costPerDistance(stats.averageCostPerDistance, unit: unit, code: currency))
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Totals")
                            .font(.headline)
                        row("Fill-ups", "\(stats.fillUpCount)")
                        row("Fuel", Formatters.liters(stats.totalLiters))
                        row("Distance", Formatters.odometer(stats.totalDistance, unit: unit))
                        row("Fuel spend", Formatters.currency(stats.totalSpend, code: currency))
                        row("Open reminders", "\(vehicle.openReminders.count)")
                    }
                }

                if !vehicle.openReminders.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Upcoming")
                                .font(.headline)
                            ForEach(vehicle.openReminders.prefix(3)) { reminder in
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundStyle(GlassTheme.accentWarm)
                                    Text(reminder.title)
                                    Spacer()
                                    if let due = reminder.dueDate {
                                        Text(due.formatted(date: .abbreviated, time: .omitted))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
