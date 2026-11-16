import SwiftData
import SwiftUI

struct TripListView: View {
    let vehicle: Vehicle

    var body: some View {
        Group {
            if vehicle.sortedTrips.isEmpty {
                ContentUnavailableView(
                    "No trips yet",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                    description: Text("Start a trip from Home to record distance, speed, and your route.")
                )
            } else {
                List {
                    ForEach(vehicle.sortedTrips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip, unit: vehicle.odometerUnit)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Formatters.shortDate(trip.startedAt))
                                    .font(.headline)
                                Text("\(Formatters.tripDistance(trip.distance, unit: vehicle.odometerUnit)) · \(Formatters.tripDuration(trip.durationSeconds)) · \(Formatters.consumptionMPG(trip.estimatedMPG))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Trip Logger")
        .fuelTrackScreen()
    }
}