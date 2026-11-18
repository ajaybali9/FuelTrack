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
            VStack(alignment: .leading, spacing: 18) {
                InstrumentSectionHeader(title: Formatters.shortDate(trip.startedAt), tint: GlassTheme.accent)
                    .staggeredAppear(index: 0)

                GlassCard(padding: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        distanceChip
                        GlassStatChip(title: "Duration", value: Formatters.tripDuration(trip.durationSeconds))
                        GlassStatChip(title: "Avg speed", value: Formatters.tripSpeed(trip.averageSpeed, unit: unit))
                        GlassStatChip(title: "Max speed", value: Formatters.tripSpeed(trip.maxSpeed, unit: unit))
                        GlassStatChip(
                            title: "Est. MPG",
                            value: Formatters.consumptionMPG(trip.estimatedMPG),
                            tint: GlassTheme.accentWarm
                        )
                        GlassStatChip(
                            title: "Est. L/100",
                            value: Formatters.consumptionL100(trip.estimatedLitersPer100km)
                        )
                    }
                }
                .staggeredAppear(index: 1)

                InstrumentSectionHeader(title: "Route", tint: GlassTheme.accent)
                    .staggeredAppear(index: 2)

                if coordinates.count >= 2 {
                    GlassCard(padding: 0) {
                        Map(position: $position) {
                            MapPolyline(coordinates: coordinates)
                                .stroke(
                                    LinearGradient(
                                        colors: [GlassTheme.accent, GlassTheme.accentWarm],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 4
                                )
                            if let first = coordinates.first {
                                Marker("Start", coordinate: first)
                                    .tint(GlassTheme.accent)
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
                    }
                    .staggeredAppear(index: 3)
                } else {
                    InstrumentListRow(tint: GlassTheme.accent.opacity(0.6)) {
                        Text("Not enough GPS points to draw this route.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .staggeredAppear(index: 3)
                }
            }
            .padding(FuelTrackTokens.horizontalPadding)
            .padding(.bottom, 8)
        }
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackScreen()
    }

    private var distanceChip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DISTANCE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(Formatters.tripDistance(trip.distance, unit: unit))
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundStyle(GlassTheme.accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(GlassTheme.accent.opacity(0.85))
                .frame(width: 28, height: 3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
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