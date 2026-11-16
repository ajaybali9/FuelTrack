import SwiftData
import SwiftUI

@main
struct FuelTrackApp: App {
    private let activeVehicleStore = ActiveVehicleStore()
    private let locationProvider = LocationProvider()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vehicle.self,
            FillUp.self,
            CarCost.self,
            ReminderItem.self,
            PersonalExpense.self,
            PersonalBudget.self,
            CustomExpenseCategory.self,
            SavedStation.self,
            Trip.self,
            TripPoint.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let url = configuration.url
            try? FileManager.default.removeItem(at: url)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(activeVehicleStore)
                .environment(locationProvider)
        }
        .modelContainer(sharedModelContainer)
    }
}
