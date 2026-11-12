import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.33percent")
                }

            FillUpListView()
                .tabItem {
                    Label("Fill-ups", systemImage: "fuelpump")
                }

            VehicleListView()
                .tabItem {
                    Label("Vehicles", systemImage: "car.side")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            _ = activeVehicleStore.resolve(from: vehicles)
        }
        .onChange(of: vehicles.map(\.id)) { _, _ in
            _ = activeVehicleStore.resolve(from: vehicles)
        }
    }
}
