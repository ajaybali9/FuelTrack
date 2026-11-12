import SwiftData
import SwiftUI

@main
struct FuelTrackApp: App {
    private let activeVehicleStore = ActiveVehicleStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Vehicle.self, FillUp.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(activeVehicleStore)
        }
        .modelContainer(sharedModelContainer)
    }
}
