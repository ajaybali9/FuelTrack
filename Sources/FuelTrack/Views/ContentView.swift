import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case home, fuel, spend, stations, more
}

struct ContentView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @AppStorage("appearancePreference") private var appearancePreference = AppearancePreference.system.rawValue
    @State private var selectedTab: AppTab = .home

    private var preferredScheme: ColorScheme? {
        AppearancePreference(rawValue: appearancePreference)?.colorScheme
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            FillUpListView()
                .tabItem { Label("Fuel", systemImage: "fuelpump.fill") }
                .tag(AppTab.fuel)

            SpendRootView()
                .tabItem { Label("Spend", systemImage: "creditcard.fill") }
                .tag(AppTab.spend)

            NearbyStationsView()
                .tabItem { Label("Stations", systemImage: "mappin.and.ellipse") }
                .tag(AppTab.stations)

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(AppTab.more)
        }
        .tint(GlassTheme.accent)
        .preferredColorScheme(preferredScheme)
        .animation(.smooth(duration: 0.32), value: selectedTab)
        .animation(.smooth(duration: 0.4), value: appearancePreference)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onAppear {
            _ = activeVehicleStore.resolve(from: vehicles)
            Task {
                await ComplianceNotificationScheduler.reschedule(for: vehicles)
            }
        }
        .onChange(of: vehicles.map(\.id)) { _, _ in
            _ = activeVehicleStore.resolve(from: vehicles)
            Task {
                await ComplianceNotificationScheduler.reschedule(for: vehicles)
            }
        }
        .onChange(of: complianceSignature) { _, _ in
            Task {
                await ComplianceNotificationScheduler.reschedule(for: vehicles)
            }
        }
    }

    /// Rebuild alerts when MOT / tax / insurance dates change.
    private var complianceSignature: String {
        vehicles
            .map { vehicle in
                [
                    vehicle.id.uuidString,
                    String(Int(vehicle.motExpiry?.timeIntervalSince1970 ?? 0)),
                    String(Int(vehicle.taxDueDate?.timeIntervalSince1970 ?? 0)),
                    String(Int(vehicle.insuranceExpiry?.timeIntervalSince1970 ?? 0)),
                ].joined(separator: "|")
            }
            .joined(separator: ";")
    }
}
