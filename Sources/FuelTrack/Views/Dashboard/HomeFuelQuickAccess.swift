import SwiftUI

struct HomeFuelQuickAccess: View {
    let vehicle: Vehicle

    @Environment(LocationProvider.self) private var locationProvider

    @State private var cheapest: NearbyStation?
    @State private var nearest: NearbyStation?
    @State private var fuelCode: String = "E10"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    private var resolvedFuel: FuelType {
        vehicle.fuelType.supportsNearbyPrices ? vehicle.fuelType : .petrolE10
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Fuel nearby", systemImage: "fuelpump.fill")
                        .font(.headline)
                    Spacer()
                    Text(resolvedFuel.shortName)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }

                if !resolvedFuel.supportsNearbyPrices {
                    Text("This car’s fuel type doesn’t have UK pump-price data. Switch to E10 / E5 / Diesel for live prices.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if isLoading && cheapest == nil && nearest == nil {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Finding best prices…")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                } else if let errorMessage, cheapest == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        Button("Try again") {
                            Task { await reload(forceLocation: true) }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                } else {
                    if let cheapest {
                        stationRow(
                            badge: "Cheapest",
                            badgeTint: GlassTheme.accentWarm,
                            station: cheapest
                        )
                    }
                    if let nearest, nearest.id != cheapest?.id {
                        stationRow(
                            badge: "Nearest",
                            badgeTint: GlassTheme.accent,
                            station: nearest
                        )
                    }
                    if cheapest == nil && nearest == nil {
                        Text("No stations found nearby. Open Stations to widen the search.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("UK pump prices · \(resolvedFuel.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button {
                        Task { await reload(forceLocation: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task(id: vehicle.id) {
            await reload(forceLocation: !didLoad)
            didLoad = true
        }
        .onChange(of: vehicle.fuelTypeRaw) { _, _ in
            Task { await reload(forceLocation: false) }
        }
        .onChange(of: locationProvider.coordinate?.latitude) { _, _ in
            Task { await reload(forceLocation: false) }
        }
    }

    private func stationRow(badge: String, badgeTint: Color, station: NearbyStation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(badge.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(badgeTint)
                Text(station.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let price = station.pricePence {
                        Text(String(format: "%.1fp/L", price))
                            .font(.title3.weight(.bold))
                    }
                    if let miles = station.distanceMiles {
                        Text("· \(String(format: "%.1f mi", miles))")
                            .foregroundStyle(.secondary)
                    }
                }
                if !station.postcode.isEmpty || !station.brand.isEmpty {
                    Text([station.brand, station.postcode].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if let url = station.mapsURL {
                Link(destination: url) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.title3)
                        .foregroundStyle(GlassTheme.accent)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }

    @MainActor
    private func reload(forceLocation: Bool) async {
        guard let fuelCode = resolvedFuel.nearbyAPIFuelCode else {
            cheapest = nil
            nearest = nil
            errorMessage = nil
            return
        }
        self.fuelCode = fuelCode

        if forceLocation || locationProvider.coordinate == nil {
            locationProvider.requestAccessIfNeeded()
            locationProvider.refresh()
            try? await Task.sleep(nanoseconds: 600_000_000)
        }

        guard let coordinate = locationProvider.coordinate else {
            if locationProvider.isAuthorized {
                errorMessage = locationProvider.lastError ?? "Waiting for location…"
            } else if locationProvider.authorizationStatus == .notDetermined {
                errorMessage = "Allow location to see nearby fuel prices."
            } else {
                errorMessage = "Enable Location for FuelTrack to show nearby prices."
            }
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let cheapestTask = NearbyStationsService.fetch(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                fuelCode: fuelCode,
                radiusMiles: 10,
                limit: 15
            )
            // Reuse cheapest response: API already sorts by price; pick nearest from same set.
            let response = try await cheapestTask
            let stations = response.stations
            cheapest = stations.first
            nearest = stations.min(by: { ($0.distanceMiles ?? .greatestFiniteMagnitude) < ($1.distanceMiles ?? .greatestFiniteMagnitude) })
        } catch {
            cheapest = nil
            nearest = nil
            errorMessage = error.localizedDescription
        }
    }
}
