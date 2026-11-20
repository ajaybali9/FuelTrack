import MapKit
import SwiftUI

private struct GarageRadiusOption: Hashable, Identifiable, CustomStringConvertible {
    let miles: Int
    var id: Int { miles }
    var description: String { "\(miles) mi" }

    static let all: [GarageRadiusOption] = [5, 10, 20].map { GarageRadiusOption(miles: $0) }

    init(miles: Int) {
        self.miles = miles
    }
}

private enum GaragesDisplayMode: String, CaseIterable, Identifiable {
    case list
    case map

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .map: "map"
        }
    }
}

struct NearbyGaragesView: View {
    @Environment(LocationProvider.self) private var locationProvider

    @State private var filter: NearbyGarageFilter = .all
    @State private var radiusMiles = 10
    @State private var garages: [NearbyGarage] = []
    @State private var region: GarageRegion = .elsewhere
    @State private var registerBuiltAt: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didLoadOnce = false
    @State private var searchText = ""
    @State private var displayMode: GaragesDisplayMode = .list
    @State private var selectedGarage: NearbyGarage?
    @State private var mapPosition: MapCameraPosition = .automatic

    private var filteredGarages: [NearbyGarage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return garages }
        return garages.filter { garage in
            [garage.name, garage.town, garage.postcode, garage.address]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query)
        }
    }

    private var radiusSelection: Binding<GarageRadiusOption> {
        Binding(
            get: { GarageRadiusOption(miles: radiusMiles) },
            set: { radiusMiles = $0.miles }
        )
    }

    var body: some View {
        Group {
            if !locationProvider.isAuthorized && locationProvider.authorizationStatus != .notDetermined {
                ContentUnavailableView(
                    "Location needed",
                    systemImage: "location.slash",
                    description: Text("Enable Location for FuelTrack in Settings to find nearby garages.")
                )
            } else if region == .elsewhere, !isLoading, errorMessage != nil || didLoadOnce {
                ContentUnavailableView(
                    "UK & Europe",
                    systemImage: "globe.europe.africa",
                    description: Text(GarageRegion.elsewhere.unavailableMessage)
                )
            } else if displayMode == .map {
                garagesMap
                    .smoothContentTransition()
            } else {
                garagesList
                    .smoothContentTransition()
            }
        }
        .id(displayMode)
        .animation(.smooth(duration: 0.32), value: displayMode)
        .navigationTitle("Nearby garages")
        .fuelTrackScreen()
        .searchable(text: $searchText, prompt: "Name, town or postcode")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("View", selection: $displayMode) {
                    ForEach(GaragesDisplayMode.allCases) { mode in
                        Image(systemName: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 90)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await reload(forceLocation: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh garages")
                .disabled(isLoading)
            }
        }
        .safeAreaInset(edge: .top) {
            controls
        }
        .sheet(item: $selectedGarage) { garage in
            NavigationStack {
                GarageDetailSheet(garage: garage, registerBuiltAt: registerBuiltAt)
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            locationProvider.requestAccessIfNeeded()
            if !didLoadOnce {
                didLoadOnce = true
                await reload(forceLocation: false)
            }
        }
        .onChange(of: locationProvider.coordinate?.latitude) { _, _ in
            Task { await reload(forceLocation: false) }
        }
        .onChange(of: filter) { _, _ in
            Task { await reload(forceLocation: false) }
        }
        .onChange(of: radiusMiles) { _, _ in
            Task { await reload(forceLocation: false) }
        }
        .onChange(of: displayMode) { _, mode in
            if mode == .map { updateMapCamera() }
        }
        .onChange(of: garages.count) { _, _ in
            if displayMode == .map { updateMapCamera() }
        }
    }

    private var controls: some View {
        GlassCard(padding: 12) {
            VStack(spacing: 12) {
                FTChipPicker(
                    label: "Show",
                    selection: $filter,
                    options: NearbyGarageFilter.allCases
                )
                FTChipPicker(
                    label: "Radius",
                    selection: radiusSelection,
                    options: GarageRadiusOption.all
                )
            }
        }
        .padding(.horizontal, FuelTrackTokens.horizontalPadding)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var garagesList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if isLoading && garages.isEmpty {
                    ProgressView("Finding nearby garages…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let errorMessage, filteredGarages.isEmpty {
                    ContentUnavailableView(
                        "Couldn’t load garages",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .padding(.top, 24)
                } else if filteredGarages.isEmpty {
                    ContentUnavailableView(
                        "No garages nearby",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Try widening the radius or switching the filter.")
                    )
                    .padding(.top, 24)
                } else {
                    InstrumentSectionHeader(
                        title: "Nearby · \(filteredGarages.count)",
                        tint: GlassTheme.accent
                    )
                    ForEach(filteredGarages) { garage in
                        Button {
                            selectedGarage = garage
                        } label: {
                            GarageRow(garage: garage)
                        }
                        .buttonStyle(.plain)
                    }

                    if let registerBuiltAt, filter != .repair {
                        Text("MOT centres from the DVSA Active MOT register · as of \(registerBuiltAt.prefix(10)). Contains public sector information licensed under the Open Government Licence v3.0.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, FuelTrackTokens.horizontalPadding)
            .padding(.bottom, 28)
        }
    }

    private var garagesMap: some View {
        Map(position: $mapPosition, selection: $selectedGarage) {
            UserAnnotation()
            ForEach(filteredGarages) { garage in
                Marker(garage.name, coordinate: garage.coordinate)
                    .tint(garage.source == .dvsa ? GlassTheme.accent : GlassTheme.accentWarm)
                    .tag(garage)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .overlay(alignment: .bottom) {
            if filteredGarages.isEmpty {
                Text(isLoading ? "Searching…" : "No garages in this area")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 24)
            }
        }
    }

    private func updateMapCamera() {
        let coords = filteredGarages.map(\.coordinate)
        guard let first = coords.first else {
            if let coordinate = locationProvider.coordinate {
                mapPosition = .region(
                    MKCoordinateRegion(center: coordinate, latitudinalMeters: 8_000, longitudinalMeters: 8_000)
                )
            }
            return
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coordinate in coords {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        if let user = locationProvider.coordinate {
            minLat = min(minLat, user.latitude)
            maxLat = max(maxLat, user.latitude)
            minLon = min(minLon, user.longitude)
            maxLon = max(maxLon, user.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.02)
        )
        mapPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    @MainActor
    private func reload(forceLocation: Bool) async {
        if forceLocation || locationProvider.coordinate == nil {
            locationProvider.requestAccessIfNeeded()
            locationProvider.refresh()
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        guard let coordinate = locationProvider.coordinate else {
            if locationProvider.authorizationStatus == .notDetermined {
                errorMessage = nil
            } else if !locationProvider.isAuthorized {
                errorMessage = "Location access is off. Enable it in Settings to find nearby garages."
            } else {
                errorMessage = locationProvider.lastError ?? "Waiting for a GPS fix…"
            }
            return
        }

        region = GarageRegion.classify(coordinate)
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await NearbyGaragesService.fetch(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                filter: filter,
                radiusMiles: radiusMiles,
                limit: 50
            )
            garages = response.garages
            region = response.region
            registerBuiltAt = response.registerBuiltAt
            if displayMode == .map {
                updateMapCamera()
            }
        } catch let error as NearbyGaragesError {
            garages = []
            if case .regionUnsupported(let unsupported) = error {
                region = unsupported
            }
            errorMessage = error.localizedDescription
        } catch {
            garages = []
            errorMessage = error.localizedDescription
        }
    }
}

private struct GarageRow: View {
    let garage: NearbyGarage

    var body: some View {
        InstrumentListRow(tint: garage.source == .dvsa ? GlassTheme.accent : GlassTheme.accentWarm) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(garage.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    if let miles = garage.distanceMiles {
                        Text(String(format: "%.1f mi", miles))
                            .font(FuelTrackTokens.numericFont(size: .subheadline))
                            .foregroundStyle(.secondary)
                    }
                }

                if !garage.displayAddress.isEmpty {
                    Text(garage.displayAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    ForEach(Array(garage.kinds).sorted(by: { $0.rawValue < $1.rawValue })) { kind in
                        Label(kind.description, systemImage: kind.systemImage)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular, in: .capsule)
                    }
                    Text(garage.sourceLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    if !garage.motClasses.isEmpty {
                        Text("Class \(garage.motClasses.map(String.init).joined(separator: "/"))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

private struct GarageDetailSheet: View {
    let garage: NearbyGarage
    var registerBuiltAt: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(garage.name)
                        .font(.title3.weight(.bold))
                    if !garage.displayAddress.isEmpty {
                        Text(garage.displayAddress)
                            .foregroundStyle(.secondary)
                    }
                    if let miles = garage.distanceMiles {
                        Label(String(format: "%.1f miles away", miles), systemImage: "location")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section("Actions") {
                if let url = garage.mapsURL {
                    Link(destination: url) {
                        Label("Directions in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                }
                if let phoneURL = garage.phoneURL {
                    Link(destination: phoneURL) {
                        Label(garage.phone, systemImage: "phone.fill")
                    }
                }
            }

            Section("Details") {
                LabeledContent("Source", value: garage.sourceLabel)
                if !garage.motClasses.isEmpty {
                    LabeledContent(
                        "MOT classes",
                        value: garage.motClasses.map(String.init).joined(separator: ", ")
                    )
                }
                ForEach(Array(garage.kinds).sorted(by: { $0.rawValue < $1.rawValue })) { kind in
                    Label(kind.description, systemImage: kind.systemImage)
                }
            }

            if garage.source == .dvsa {
                Section {
                    Text("Official DVSA Active MOT register\(registerBuiltAt.map { " · as of \($0.prefix(10))" } ?? ""). Public sector information licensed under the OGL v3.0.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Text("Listing from Apple Maps. Not an official MOT authorisation record unless also shown from the DVSA register.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Garage")
        .navigationBarTitleDisplayMode(.inline)
    }
}
