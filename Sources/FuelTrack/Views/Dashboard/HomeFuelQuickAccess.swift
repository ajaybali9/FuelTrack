import SwiftUI

struct HomeFuelQuickAccess: View {
    let vehicle: Vehicle

    @Environment(LocationProvider.self) private var locationProvider

    @State private var topStations: [NearbyStation] = []
    @State private var nearest: NearbyStation?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    private var showsLivePrices: Bool { vehicle.fuelType.supportsNearbyPrices }

    private var cheapestID: String? { topStations.first?.id }

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label("Fuel nearby", systemImage: "fuelpump.fill")
                        .font(.headline)
                    Spacer(minLength: 0)
                    Text(vehicle.fuelType.shortName)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    Button {
                        Task { await reload(forceLocation: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    .disabled(isLoading)
                }

                if !showsLivePrices {
                    Text("Switch fuel to E10 / E5 / Diesel for live UK pump prices.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if isLoading && topStations.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Finding best prices…")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } else if let errorMessage, topStations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button("Try again") {
                            Task { await reload(forceLocation: true) }
                        }
                        .font(.caption.weight(.semibold))
                    }
                } else if topStations.isEmpty {
                    Text("No stations nearby. Open Stations to widen the search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    if let nearest {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(GlassTheme.accent)
                            Text("Nearest \(nearest.name)")
                                .lineLimit(1)
                            if let miles = nearest.distanceMiles {
                                Text("· \(String(format: "%.1f mi", miles))")
                            }
                            if let price = nearest.pricePence {
                                Text("· \(String(format: "%.0fp", price))")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(topStations.enumerated()), id: \.element.id) { index, station in
                                compactStationChip(
                                    rank: index + 1,
                                    station: station,
                                    isBest: station.id == cheapestID
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
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

    private func compactStationChip(rank: Int, station: NearbyStation, isBest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("#\(rank)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(isBest ? GlassTheme.accentWarm : .secondary)
                if isBest {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(GlassTheme.accentWarm)
                }
                Spacer(minLength: 0)
                if let url = station.mapsURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.accent)
                    }
                }
            }

            if let price = station.pricePence {
                Text(String(format: "%.1fp", price))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            Text(station.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 28, alignment: .top)

            HStack(spacing: 4) {
                if let miles = station.distanceMiles {
                    Label(String(format: "%.1f mi", miles), systemImage: "location")
                }
                if !station.brand.isEmpty {
                    Text("· \(station.brand)")
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(width: 132, alignment: .leading)
        .glassEffect(
            isBest ? .regular.tint(GlassTheme.accentWarm.opacity(0.35)).interactive() : .regular.interactive(),
            in: .rect(cornerRadius: 16)
        )
    }

    @MainActor
    private func reload(forceLocation: Bool) async {
        guard let fuelCode = vehicle.fuelType.nearbyAPIFuelCode else {
            topStations = []
            nearest = nil
            errorMessage = nil
            return
        }

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
            let response = try await NearbyStationsService.fetch(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                fuelCode: fuelCode,
                radiusMiles: 10,
                limit: 20
            )
            let stations = response.stations
            topStations = Array(stations.prefix(5))
            nearest = stations.min(by: {
                ($0.distanceMiles ?? .greatestFiniteMagnitude) < ($1.distanceMiles ?? .greatestFiniteMagnitude)
            })
        } catch {
            topStations = []
            nearest = nil
            errorMessage = error.localizedDescription
        }
    }
}
