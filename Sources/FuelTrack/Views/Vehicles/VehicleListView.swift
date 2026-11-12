import SwiftData
import SwiftUI

struct VehicleListView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @State private var showingAdd = false

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    ContentUnavailableView(
                        "No vehicles yet",
                        systemImage: "car.side",
                        description: Text("Add a car to start tracking fuel.")
                    )
                } else {
                    List {
                        ForEach(vehicles) { vehicle in
                            NavigationLink {
                                VehicleFormView(vehicle: vehicle)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(vehicle.name)
                                            .font(.headline)
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
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onLongPressGesture {
                                    activeVehicleStore.select(vehicle)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    activeVehicleStore.select(vehicle)
                                } label: {
                                    Label("Active", systemImage: "checkmark.circle")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Vehicles")
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
        }
    }

    private func delete(at offsets: IndexSet) {
        let remaining = vehicles.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)

        for index in offsets {
            let vehicle = vehicles[index]
            if activeVehicleStore.activeVehicleID == vehicle.id {
                activeVehicleStore.activeVehicleID = nil
            }
            modelContext.delete(vehicle)
        }
        try? modelContext.save()
        _ = activeVehicleStore.resolve(from: remaining)
    }
}
