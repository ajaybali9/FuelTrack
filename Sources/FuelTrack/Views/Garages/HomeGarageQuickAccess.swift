import SwiftUI

struct HomeGarageQuickAccess: View {
    @Environment(LocationProvider.self) private var locationProvider

    @State private var topGarages: [NearbyGarage] = []
    @State private var nearest: NearbyGarage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var regionUnsupported = false
    @State private var didLoad = false

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label("Garages nearby", systemImage: "wrench.and.screwdriver.fill")
                        .font(.headline)
                    Spacer(minLength: 0)
                    Button {
                        Task { await reload(forceLocation: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    .accessibilityLabel("Refresh nearby garages")
                    .disabled(isLoading)
                }

                if regionUnsupported {
                    Text(GarageRegion.elsewhere.unavailableMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if isLoading && topGarages.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Finding nearby garages…")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } else if let errorMessage, topGarages.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button("Try again") {
                            Task { await reload(forceLocation: true) }
                        }
                        .font(.caption.weight(.semibold))
                    }
                } else if topGarages.isEmpty {
                    Text("No garages nearby. Open Nearby garages to widen the search.")
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
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(topGarages) { garage in
                                compactGarageChip(garage)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                NavigationLink {
                    NearbyGaragesView()
                } label: {
                    Text("Open Nearby garages")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(GlassTheme.accent)
            }
        }
        .task {
            await reload(forceLocation: !didLoad)
            didLoad = true
        }
        .onChange(of: locationProvider.coordinate?.latitude) { _, _ in
            Task { await reload(forceLocation: false) }
        }
    }

    private func compactGarageChip(_ garage: NearbyGarage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if garage.kinds.contains(.mot) {
                    Image(systemName: "checklist")
                        .font(.caption2)
                        .foregroundStyle(GlassTheme.accent)
                } else {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.caption2)
                        .foregroundStyle(GlassTheme.accentWarm)
                }
                Spacer(minLength: 0)
                if let url = garage.mapsURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.accent)
                    }
                }
            }

            Text(garage.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 28, alignment: .top)

            HStack(spacing: 4) {
                if let miles = garage.distanceMiles {
                    Label(String(format: "%.1f mi", miles), systemImage: "location")
                }
                Text("· \(garage.sourceLabel)")
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(width: 148, alignment: .leading)
        .glassEffect(
            garage.source == .dvsa
                ? .regular.tint(GlassTheme.accent.opacity(0.28)).interactive()
                : .regular.interactive(),
            in: .rect(cornerRadius: 16)
        )
    }

    @MainActor
    private func reload(forceLocation: Bool) async {
        regionUnsupported = false

        if forceLocation || locationProvider.coordinate == nil {
            locationProvider.requestAccessIfNeeded()
            locationProvider.refresh()
            try? await Task.sleep(nanoseconds: 600_000_000)
        }

        guard let coordinate = locationProvider.coordinate else {
            if locationProvider.isAuthorized {
                errorMessage = locationProvider.lastError ?? "Waiting for location…"
            } else if locationProvider.authorizationStatus == .notDetermined {
                errorMessage = "Allow location to see nearby garages."
            } else {
                errorMessage = "Enable Location for FuelTrack to show nearby garages."
            }
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await NearbyGaragesService.fetch(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                filter: .all,
                radiusMiles: 10,
                limit: 20
            )
            topGarages = Array(response.garages.prefix(5))
            nearest = response.garages.min(by: {
                ($0.distanceMiles ?? .greatestFiniteMagnitude) < ($1.distanceMiles ?? .greatestFiniteMagnitude)
            })
        } catch let error as NearbyGaragesError {
            topGarages = []
            nearest = nil
            if case .regionUnsupported = error {
                regionUnsupported = true
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            topGarages = []
            nearest = nil
            errorMessage = error.localizedDescription
        }
    }
}
