import SwiftData
import SwiftUI

struct VehicleListView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @State private var showingAdd = false
    @State private var vehiclePendingDelete: Vehicle?
    @State private var showDeleteConfirm = false

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    var body: some View {
        Group {
            if vehicles.isEmpty {
                ContentUnavailableView {
                    Label("No vehicles yet", systemImage: "car.side")
                } description: {
                    Text("Add a car to start tracking fuel, spend, and UK compliance.")
                } actions: {
                    Button("Add vehicle") { showingAdd = true }
                        .buttonStyle(.borderedProminent)
                        .tint(GlassTheme.accent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(vehicles.enumerated()), id: \.element.id) { index, vehicle in
                            HStack(spacing: 10) {
                                NavigationLink {
                                    VehicleFormView(vehicle: vehicle)
                                } label: {
                                    vehicleCard(vehicle)
                                }
                                .buttonStyle(.plain)
                                .staggeredAppear(index: index)

                                Button {
                                    vehiclePendingDelete = vehicle
                                    showDeleteConfirm = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                        .frame(width: 44, height: 44)
                                        .glassEffect(.regular.interactive(), in: .circle)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete \(vehicle.name)")
                            }
                            .contextMenu {
                                Button("Set Active") { activeVehicleStore.select(vehicle) }
                                Button("Delete", role: .destructive) {
                                    vehiclePendingDelete = vehicle
                                    showDeleteConfirm = true
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Vehicles")
        .fuelTrackScreen()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                VehicleFormView(vehicle: nil)
            }
        }
        .confirmationDialog(
            "Delete this vehicle?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete vehicle", role: .destructive) {
                if let vehiclePendingDelete {
                    delete(vehiclePendingDelete)
                }
            }
            Button("Cancel", role: .cancel) {
                vehiclePendingDelete = nil
            }
        } message: {
            Text("This removes the car and all linked fill-ups, costs, and reminders.")
        }
    }

    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        let makeModel = [vehicle.make, vehicle.model].filter { !$0.isEmpty }.joined(separator: " · ")
        return InstrumentListRow(tint: GlassTheme.accent) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(vehicle.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if vehicle.id == activeVehicle?.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.accent)
                        }
                    }
                    if !vehicle.registrationPlate.isEmpty {
                        Text(vehicle.displayPlate)
                            .font(FuelTrackTokens.plateFont())
                            .tracking(1.2)
                            .foregroundStyle(GlassTheme.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.yellow.opacity(0.9))
                            }
                    }
                    if !makeModel.isEmpty {
                        Text(makeModel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if vehicle.registrationPlate.isEmpty {
                        Text(vehicle.fuelType.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(vehicle.currencyCode.rawValue) · \(vehicle.odometerUnit.displayName)")
                        .font(FuelTrackTokens.numericFont(size: .caption))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func delete(_ vehicle: Vehicle) {
        if activeVehicleStore.activeVehicleID == vehicle.id {
            activeVehicleStore.activeVehicleID = nil
        }
        modelContext.delete(vehicle)
        try? modelContext.save()
        vehiclePendingDelete = nil
        _ = activeVehicleStore.resolve(from: vehicles.filter { $0.id != vehicle.id })
    }
}
