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
                ContentUnavailableView(
                    "No vehicles yet",
                    systemImage: "car.side",
                    description: Text("Add a car to start tracking fuel.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vehicles) { vehicle in
                            HStack(spacing: 10) {
                                NavigationLink {
                                    VehicleFormView(vehicle: vehicle)
                                } label: {
                                    GlassCard {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(vehicle.name)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                Text(vehicle.displaySubtitle)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                Text("\(vehicle.currencyCode.rawValue) · \(vehicle.odometerUnit.displayName)")
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            Spacer()
                                            if vehicle.id == activeVehicle?.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(GlassTheme.accent)
                                            }
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

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
            Button("Delete Vehicle", role: .destructive) {
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
