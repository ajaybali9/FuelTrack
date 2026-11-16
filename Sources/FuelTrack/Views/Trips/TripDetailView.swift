import MapKit
import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    let unit: OdometerUnit

    @State private var position: MapCameraPosition = .automatic

    private var coordinates: [CLLocationCoordinate2D] {
        trip.sortedPoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    GlassStatChip(title: "Distance", value: Formatters.tripDistance(trip.distance, unit: unit))
                    GlassStatChip(title: "Duration", value: Formatters.tripDuration(trip.durationSeconds))
                    GlassStatChip(title: "Avg speed", value: Formatters.tripSpeed(trip.averageSpeed, unit: unit))
                    GlassStatChip(title: "Max speed", value: Formatters.tripSpeed(trip.maxSpeed, unit: unit))
                    GlassStatChip(title: "Est. MPG", value: Formatters.consumptionMPG(trip.estimatedMPG), tint: GlassTheme.accentWarm)
                    GlassStatChip(title: "Est. L/100", value: Formatters.consumptionL100(trip.estimatedLitersPer100km))
                }

                if coordinates.count >= 2 {
                    Map(position: $position) {
                        MapPolyline(coordinates: coordinates)
                            .stroke(GlassTheme.accent, lineWidth: 4)
                        if let first = coordinates.first {
                            Marker("Start", coordinate: first)
                        }
                        if let last = coordinates.last {
                            Marker("End", coordinate: last)
                                .tint(GlassTheme.accentWarm)
                        }
                    }
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onAppear {
                        if let region = region(for: coordinates) {
                            position = .region(region)
                        }
                    }
                } else {
                    Text("Not enough GPS points to draw this route.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackScreen()
    }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        for c in coordinates.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}