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
            .navigationTitle("Fuel Computer")
            .navigationBarTitleDisplayMode(.inline)
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
            VStack(spacing: 18) {
                InstrumentHeroCluster(
                    vehicleName: vehicle.name,
                    subtitle: vehicle.displaySubtitle,
                    odometerLine: vehicle.latestOdometer.map { "ODO \(Formatters.odometer($0, unit: unit))" },
                    primaryLabel: "Avg L/100km",
                    primaryValue: Formatters.consumptionL100(stats.averageLitersPer100km),
                    secondaryLabel: "Month fuel",
                    secondaryValue: Formatters.currency(stats.spendThisMonth, code: currency)
                )
                .staggeredAppear(index: 0)

                HomeTripCard(vehicle: vehicle)
                    .staggeredAppear(index: 1)

                if !vehicle.registrationPlate.isEmpty || vehicle.motExpiry != nil || vehicle.taxDueDate != nil || vehicle.insuranceExpiry != nil {
                    VehicleComplianceCard(vehicle: vehicle)
                        .staggeredAppear(index: 2)
                }

                InstrumentSectionHeader(title: "Nearby fuel", tint: GlassTheme.accent)
                    .staggeredAppear(index: 3)
                HomeFuelQuickAccess(vehicle: vehicle)
                    .staggeredAppear(index: 3)

                InstrumentSectionHeader(title: "Nearby garages", tint: GlassTheme.accent)
                    .staggeredAppear(index: 4)
                HomeGarageQuickAccess()
                    .staggeredAppear(index: 4)

                InstrumentSectionHeader(title: "Spend pulse", tint: GlassTheme.accentWarm)
                    .staggeredAppear(index: 5)
                HomeCarSpendCard(vehicle: vehicle)
                    .staggeredAppear(index: 5)
                HomePersonalSpendCard()
                    .staggeredAppear(index: 6)

                InstrumentSectionHeader(title: "Instrument readout")
                    .staggeredAppear(index: 7)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    GlassStatChip(title: "Avg L/100km", value: Formatters.consumptionL100(stats.averageLitersPer100km))
                    GlassStatChip(title: "Avg MPG", value: Formatters.consumptionMPG(stats.averageMPG), tint: GlassTheme.accentWarm)
                    GlassStatChip(title: "Fuel month", value: Formatters.currency(stats.spendThisMonth, code: currency))
                    GlassStatChip(title: "Car month", value: Formatters.currency(vehicle.costsThisMonth, code: currency), tint: GlassTheme.accentWarm)
                }
                .staggeredAppear(index: 7)

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        InstrumentSectionHeader(title: "Fuel economy")
                        if let last = stats.lastSegment {
                            instrumentRow("Last tank", Formatters.consumptionL100(last.litersPer100km(unit: unit)), tint: GlassTheme.accent)
                            instrumentRow("Last tank MPG", Formatters.consumptionMPG(last.mpg(unit: unit)), tint: GlassTheme.accent)
                        } else {
                            Text("Log two full tanks to see consumption.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        instrumentRow("Avg price", Formatters.pricePerLiter(stats.averagePricePerLiter, code: currency), tint: GlassTheme.accentWarm)
                        instrumentRow("Cost / distance", Formatters.costPerDistance(stats.averageCostPerDistance, unit: unit, code: currency), tint: GlassTheme.accentWarm)
                    }
                }
                .staggeredAppear(index: 8)

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        InstrumentSectionHeader(title: "Lifetime")
                        instrumentRow("Fill-ups", "\(stats.fillUpCount)", tint: GlassTheme.accent)
                        instrumentRow("Fuel", Formatters.liters(stats.totalLiters), tint: GlassTheme.accent)
                        instrumentRow("Distance", Formatters.odometer(stats.totalDistance, unit: unit), tint: GlassTheme.accent)
                        instrumentRow("Fuel spend", Formatters.currency(stats.totalSpend, code: currency), tint: GlassTheme.accentWarm)
                        instrumentRow("Open reminders", "\(vehicle.openReminders.count)", tint: GlassTheme.accentWarm)
                    }
                }
                .staggeredAppear(index: 9)

                if !vehicle.openReminders.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            InstrumentSectionHeader(title: "Upcoming", tint: GlassTheme.accentWarm)
                            ForEach(vehicle.openReminders.prefix(3)) { reminder in
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundStyle(GlassTheme.accentWarm)
                                    Text(reminder.title)
                                    Spacer()
                                    if let due = reminder.dueDate {
                                        Text(due.formatted(date: .abbreviated, time: .omitted))
                                            .font(FuelTrackTokens.numericFont(size: .caption))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .staggeredAppear(index: 9)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 28)
        }
    }

    private func instrumentRow(_ title: String, _ value: String, tint: Color) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(FuelTrackTokens.numericFont(size: .body))
                .foregroundStyle(tint)
        }
        .font(.subheadline)
    }
}
