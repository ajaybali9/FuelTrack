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
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        InstrumentSectionHeader(title: "Trip history", tint: GlassTheme.accent)
                        ForEach(Array(vehicle.sortedTrips.enumerated()), id: \.element.id) { index, trip in
                            NavigationLink {
                                TripDetailView(trip: trip, unit: vehicle.odometerUnit)
                            } label: {
                                InstrumentListRow(tint: GlassTheme.accent) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(Formatters.shortDate(trip.startedAt))
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text(Formatters.tripDistance(trip.distance, unit: vehicle.odometerUnit))
                                                .font(FuelTrackTokens.numericFont(size: .body))
                                                .foregroundStyle(GlassTheme.accent)
                                        }
                                        Text("\(Formatters.tripDuration(trip.durationSeconds)) · \(Formatters.consumptionMPG(trip.estimatedMPG))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .staggeredAppear(index: min(index + 1, 10))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("Trips")
        .fuelTrackScreen()
    }
}
