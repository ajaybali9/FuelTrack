import MapKit
import SwiftData
import SwiftUI

private struct StationRadiusOption: Hashable, Identifiable, CustomStringConvertible {
    let miles: Int
    var id: Int { miles }
    var description: String { "\(miles) mi" }

    static let all: [StationRadiusOption] = [5, 10, 20].map { StationRadiusOption(miles: $0) }

    init(miles: Int) {
        self.miles = miles
    }
}

private enum StationsDisplayMode: String, CaseIterable, Identifiable {
    case list
    case map

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: "List"
        case .map: "Map"
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .map: "map"
        }
    }
}

struct NearbyStationsView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(sort: \FillUp.date, order: .reverse) private var fillUps: [FillUp]
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @Environment(LocationProvider.self) private var locationProvider

    @State private var fuelType: FuelType = .petrolE10
    @State private var radiusMiles = 10
    @State private var stations: [NearbyStation] = []
    @State private var lastUpdated: Date?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didLoadOnce = false
    @State private var searchText = ""
    @State private var displayMode: StationsDisplayMode = .list
    @State private var selectedStation: NearbyStation?
    @State private var selectedUsed: UsedStationSummary?
    @State private var mapPosition: MapCameraPosition = .automatic

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    private var usedStations: [UsedStationSummary] {
        UsedStations.summarize(from: fillUps)
    }

    private var filteredUsedStations: [UsedStationSummary] {
        filterUsed(UsedStations.favourites(from: fillUps))
    }

    private var filteredNearby: [NearbyStation] {
        filterNearby(stations)
    }

    private var cheapest: NearbyStation? {
        filteredNearby.first
    }

    private var mapStations: [NearbyStation] {
        var result = filteredNearby
        for used in filteredUsedStations {
            if let match = UsedStations.bestMatch(for: used, in: stations),
               !result.contains(where: { $0.id == match.id }) {
                result.append(match)
            }
        }
        return result
    }

    private var radiusSelection: Binding<StationRadiusOption> {
        Binding(
            get: { StationRadiusOption(miles: radiusMiles) },
            set: { radiusMiles = $0.miles }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if !fuelType.supportsNearbyPrices {
                    ContentUnavailableView(
                        "No pump prices",
                        systemImage: "bolt.car",
                        description: Text("Nearby price search supports Petrol E10, Super E5, and Diesel.")
                    )
                } else if !locationProvider.isAuthorized && locationProvider.authorizationStatus != .notDetermined {
                    ContentUnavailableView(
                        "Location needed",
                        systemImage: "location.slash",
                        description: Text("Enable Location for FuelTrack in Settings to find nearby stations.")
                    )
                } else if displayMode == .map {
                    stationsMap
                        .smoothContentTransition()
                } else {
                    stationsList
                        .smoothContentTransition()
                }
            }
            .id(displayMode)
            .animation(.smooth(duration: 0.32), value: displayMode)
            .navigationTitle("Stations")
            .fuelTrackScreen()
            .searchable(text: $searchText, prompt: "Name, brand or postcode")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("View", selection: $displayMode) {
                        ForEach(StationsDisplayMode.allCases) { mode in
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
                    .accessibilityLabel("Refresh stations")
                    .disabled(isLoading || !fuelType.supportsNearbyPrices)
                }
            }
            .safeAreaInset(edge: .top) {
                controls
            }
            .sheet(item: $selectedStation) { station in
                NavigationStack {
                    StationDetailSheet(
                        station: station,
                        usedSummary: bestUsed(for: station)
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedUsed) { used in
                NavigationStack {
                    UsedStationDetailSheet(summary: used, nearby: UsedStations.bestMatch(for: used, in: stations))
                }
                .presentationDetents([.medium, .large])
            }
            .task {
                if let vehicle = activeVehicle {
                    fuelType = vehicle.fuelType.supportsNearbyPrices ? vehicle.fuelType : .petrolE10
                }
                locationProvider.requestAccessIfNeeded()
                if !didLoadOnce {
                    didLoadOnce = true
                    await reload(forceLocation: false)
                }
            }
            .onChange(of: locationProvider.coordinate?.latitude) { _, _ in
                Task { await reload(forceLocation: false) }
            }
            .onChange(of: fuelType) { _, _ in
                Task { await reload(forceLocation: false) }
            }
            .onChange(of: radiusMiles) { _, _ in
                Task { await reload(forceLocation: false) }
            }
            .onChange(of: displayMode) { _, mode in
                if mode == .map {
                    updateMapCamera()
                }
            }
            .onChange(of: stations.count) { _, _ in
                if displayMode == .map {
                    updateMapCamera()
                }
            }
        }
    }

    private var controls: some View {
        GlassCard(padding: 12) {
            VStack(spacing: 12) {
                FTChipPicker(
                    label: "Fuel",
                    selection: $fuelType,
                    options: FuelType.selectableCases.filter(\.supportsNearbyPrices),
                    shortLabel: { $0.shortName }
                )
                FTChipPicker(
                    label: "Radius",
                    selection: radiusSelection,
                    options: StationRadiusOption.all
                )
            }
        }
        .padding(.horizontal, FuelTrackTokens.horizontalPadding)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var stationsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if !filteredUsedStations.isEmpty {
                    InstrumentSectionHeader(
                        title: "Favourites · \(filteredUsedStations.count)",
                        tint: GlassTheme.accentWarm
                    )
                    ForEach(Array(filteredUsedStations.enumerated()), id: \.element.id) { index, used in
                        UsedStationRow(
                            summary: used,
                            nearby: UsedStations.bestMatch(for: used, in: stations)
                        ) {
                            if let nearby = UsedStations.bestMatch(for: used, in: stations) {
                                selectedStation = nearby
                            } else {
                                selectedUsed = used
                            }
                        }
                        .staggeredAppear(index: index)
                    }
                    Text(
                        "Stations with more than \(UsedStations.minimumFavouriteVisits) fill-ups. Matched nearby pumps show today’s price when available."
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }

                if let cheapest, let price = cheapest.pricePence, searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    InstrumentSectionHeader(title: "Best price nearby", tint: GlassTheme.accentWarm)
                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(formatPence(price))
                                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                                .foregroundStyle(GlassTheme.accentWarm)
                            Text(cheapest.name)
                                .font(.headline)
                            HStack(spacing: 6) {
                                if let miles = cheapest.distanceMiles {
                                    Text(String(format: "%.1f mi", miles))
                                        .font(FuelTrackTokens.numericFont(size: .subheadline))
                                        .foregroundStyle(GlassTheme.accent)
                                }
                                if !cheapest.postcode.isEmpty {
                                    Text("· \(cheapest.postcode)")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedStation = cheapest }
                    .staggeredAppear(index: 0)
                }

                InstrumentSectionHeader(
                    title: filteredNearby.isEmpty
                        ? "Nearby"
                        : "Nearby · \(filteredNearby.count)",
                    tint: GlassTheme.accent
                )

                if isLoading && stations.isEmpty {
                    InstrumentListRow {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Finding stations…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let errorMessage {
                    InstrumentListRow(tint: GlassTheme.error) {
                        Text(errorMessage)
                            .foregroundStyle(GlassTheme.error)
                    }
                } else if filteredNearby.isEmpty {
                    InstrumentListRow {
                        Text(
                            stations.isEmpty
                                ? "No stations found in this radius. Try a wider search or check you’re in the UK."
                                : "No stations match “\(searchText)”."
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    }
                } else {
                    ForEach(Array(filteredNearby.enumerated()), id: \.element.id) { index, station in
                        Button {
                            selectedStation = station
                        } label: {
                            InstrumentListRow(
                                tint: index == 0 && searchText.isEmpty
                                    ? GlassTheme.accentWarm
                                    : GlassTheme.accent
                            ) {
                                StationRow(
                                    station: station,
                                    rank: index + 1,
                                    isBest: index == 0 && searchText.isEmpty,
                                    isUsed: isUsed(station)
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .staggeredAppear(index: index)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let lastUpdated {
                        Text("Feed updated \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    }
                    Text("UK pump prices via Cheapest Fuel (cheapestfuelnearme.co.uk). Prices in pence/litre.")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            .padding(FuelTrackTokens.horizontalPadding)
            .padding(.bottom, 12)
        }
        .refreshable {
            await reload(forceLocation: true)
        }
    }

    private var stationsMap: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapPosition, selection: $selectedStation) {
                if let coordinate = locationProvider.coordinate {
                    Annotation("You", coordinate: coordinate) {
                        Image(systemName: "location.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .padding(4)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }

                ForEach(mapStations) { station in
                    Annotation(station.name, coordinate: station.coordinate, anchor: .bottom) {
                        StationPriceMapPin(
                            priceLabel: station.pricePence.map(formatPenceShort(_:)),
                            style: mapPinStyle(for: station),
                            isSelected: selectedStation?.id == station.id
                        )
                    }
                    .tag(station)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
            }

            VStack(spacing: 10) {
                if mapStations.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No stations on map" : "No matches",
                        systemImage: "mappin.slash",
                        description: Text(
                            searchText.isEmpty
                                ? "Pull to refresh or widen the radius."
                                : "Try another name or postcode."
                        )
                    )
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .padding()
                } else {
                    mapPriceLegend
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var mapPriceLegend: some View {
        HStack(spacing: 12) {
            legendSwatch(color: GlassTheme.accent, label: "Cheapest")
            legendSwatch(color: GlassTheme.accentWarm, label: "Favourite")
            legendSwatch(color: .secondary, label: "Other")
            Spacer(minLength: 0)
            Text("Tap pin for details")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func mapPinStyle(for station: NearbyStation) -> StationPriceMapPin.Style {
        if station.id == cheapest?.id { return .cheapest }
        if isUsed(station) { return .favourite }
        return .standard
    }

    private func formatPenceShort(_ pence: Double) -> String {
        String(format: "%.0f", pence)
    }

    private func isUsed(_ station: NearbyStation) -> Bool {
        bestUsed(for: station) != nil
    }

    private func bestUsed(for station: NearbyStation) -> UsedStationSummary? {
        usedStations
            .map { ($0, UsedStations.matchScore($0, nearby: station)) }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?
            .0
    }

    private func filterNearby(_ input: [NearbyStation]) -> [NearbyStation] {
        input.filter { StationSearch.matches($0, query: searchText) }
    }

    private func filterUsed(_ input: [UsedStationSummary]) -> [UsedStationSummary] {
        input.filter { StationSearch.matchesUsed($0, query: searchText) }
    }

    private func updateMapCamera() {
        let coords = mapStations.map(\.coordinate)
        if let user = locationProvider.coordinate {
            var all = coords
            all.append(user)
            if let region = region(for: all) {
                mapPosition = .region(region)
                return
            }
        }
        if let region = region(for: coords) {
            mapPosition = .region(region)
        } else if let user = locationProvider.coordinate {
            mapPosition = .region(MKCoordinateRegion(center: user, latitudinalMeters: 8_000, longitudinalMeters: 8_000))
        }
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

    private func reload(forceLocation: Bool) async {
        guard fuelType.supportsNearbyPrices, let fuelCode = fuelType.nearbyAPIFuelCode else {
            stations = []
            return
        }

        if forceLocation || locationProvider.coordinate == nil {
            locationProvider.requestAccessIfNeeded()
            locationProvider.refresh()
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        guard let coordinate = locationProvider.coordinate else {
            if locationProvider.authorizationStatus == .notDetermined {
                errorMessage = nil
            } else if !locationProvider.isAuthorized {
                errorMessage = "Location access is off. Enable it in Settings to find nearby stations."
            } else {
                errorMessage = locationProvider.lastError ?? "Waiting for a GPS fix…"
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
                radiusMiles: radiusMiles,
                limit: 50
            )
            stations = response.stations
            lastUpdated = response.lastUpdated
            if displayMode == .map {
                updateMapCamera()
            }
        } catch {
            stations = []
            errorMessage = error.localizedDescription
        }
    }

    private func formatPence(_ pence: Double) -> String {
        String(format: "%.1fp/L", pence)
    }
}

private struct StationDetailSheet: View {
    let station: NearbyStation
    var usedSummary: UsedStationSummary?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(station.name)
                            .font(.title2.weight(.bold))
                        if !station.brand.isEmpty {
                            Text(station.brand)
                                .foregroundStyle(.secondary)
                        }
                        if let price = station.pricePence {
                            Text(String(format: "%.1fp/L", price))
                                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                                .foregroundStyle(GlassTheme.accentWarm)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                InstrumentSectionHeader(title: "Location", tint: GlassTheme.accent)
                GlassCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text([station.address, station.city, station.postcode].filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.subheadline)
                        if let miles = station.distanceMiles {
                            LabeledContent("Distance") {
                                Text(String(format: "%.1f mi", miles))
                                    .font(FuelTrackTokens.numericFont(size: .body))
                                    .foregroundStyle(GlassTheme.accent)
                            }
                        }
                        if station.is24h {
                            Label("Open 24 hours", systemImage: "clock")
                        }
                        if station.isSupermarket {
                            Label("Supermarket", systemImage: "cart")
                        }
                    }
                }

                if let usedSummary {
                    InstrumentSectionHeader(title: "Your visits", tint: GlassTheme.accentWarm)
                    GlassCard(padding: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Visits", value: "\(usedSummary.visitCount)")
                            LabeledContent("Last visit", value: Formatters.shortDate(usedSummary.lastVisit))
                            LabeledContent(
                                "Last fill",
                                value: Formatters.currency(usedSummary.lastCost, code: usedSummary.lastCurrency)
                            )
                            if let ppl = usedSummary.lastPricePerLiter {
                                LabeledContent(
                                    "Last paid",
                                    value: Formatters.pricePerLiter(ppl, code: usedSummary.lastCurrency)
                                )
                            }
                            LabeledContent(
                                "Total spent",
                                value: Formatters.currency(usedSummary.totalSpend, code: usedSummary.lastCurrency)
                            )
                        }
                    }
                }

                if let url = station.mapsURL {
                    Link(destination: url) {
                        InstrumentListRow(tint: GlassTheme.accent) {
                            Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(FuelTrackTokens.horizontalPadding)
            .padding(.bottom, 12)
        }
        .navigationTitle("Station")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackForm()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

private struct UsedStationRow: View {
    let summary: UsedStationSummary
    var nearby: NearbyStation?
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            InstrumentListRow(tint: GlassTheme.accentWarm) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(GlassTheme.accentWarm)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            Text("\(summary.visitCount)×")
                            Text("·")
                            Text("Last \(Formatters.shortDate(summary.lastVisit))")
                            if let nearby, let price = nearby.pricePence {
                                Text("·")
                                Text(String(format: "%.1fp now", price))
                                    .font(FuelTrackTokens.numericFont(size: .caption))
                                    .foregroundStyle(GlassTheme.accentWarm)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("Spent \(Formatters.currency(summary.totalSpend, code: summary.lastCurrency))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)

                    if let nearby, let url = nearby.mapsURL {
                        Link(destination: url) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .imageScale(.large)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Image(systemName: nearby == nil ? "fuelpump" : "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct UsedStationDetailSheet: View {
    let summary: UsedStationSummary
    var nearby: NearbyStation?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(summary.displayName)
                            .font(.title2.weight(.bold))
                        Text("From your fuel logs")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                InstrumentSectionHeader(title: "Your visits", tint: GlassTheme.accentWarm)
                GlassCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Visits", value: "\(summary.visitCount)")
                        LabeledContent("Last visit", value: Formatters.shortDate(summary.lastVisit))
                        LabeledContent("Last fill", value: Formatters.currency(summary.lastCost, code: summary.lastCurrency))
                        if let ppl = summary.lastPricePerLiter {
                            LabeledContent("Last paid", value: Formatters.pricePerLiter(ppl, code: summary.lastCurrency))
                        }
                        LabeledContent(
                            "Total spent",
                            value: Formatters.currency(summary.totalSpend, code: summary.lastCurrency)
                        )
                    }
                }

                if let nearby {
                    InstrumentSectionHeader(title: "Nearby match", tint: GlassTheme.accent)
                    GlassCard(padding: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let price = nearby.pricePence {
                                LabeledContent("Today") {
                                    Text(String(format: "%.1fp/L", price))
                                        .font(FuelTrackTokens.numericFont(size: .body))
                                        .foregroundStyle(GlassTheme.accentWarm)
                                }
                            }
                            if let miles = nearby.distanceMiles {
                                LabeledContent("Distance") {
                                    Text(String(format: "%.1f mi", miles))
                                        .font(FuelTrackTokens.numericFont(size: .body))
                                        .foregroundStyle(GlassTheme.accent)
                                }
                            }
                            if let url = nearby.mapsURL {
                                Link(destination: url) {
                                    Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                }
                            }
                        }
                    }
                } else {
                    InstrumentListRow {
                        Text(
                            "No matching pump in the current nearby list. Widen the radius or check the station name on your fill-up."
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    }
                }
            }
            .padding(FuelTrackTokens.horizontalPadding)
            .padding(.bottom, 12)
        }
        .navigationTitle("Your station")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackForm()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

private struct StationRow: View {
    let station: NearbyStation
    let rank: Int
    let isBest: Bool
    var isUsed: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(isBest ? GlassTheme.accentWarm : .secondary)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(station.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if isBest {
                        Text("BEST")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(GlassTheme.accentWarm)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(GlassTheme.accentWarm.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    if isUsed {
                        Text("USED")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(GlassTheme.accentWarm.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                if let price = station.pricePence {
                    Text(String(format: "%.1fp/L", price))
                        .font(FuelTrackTokens.numericFont(size: .title3))
                        .foregroundStyle(isBest ? GlassTheme.accentWarm : .primary)
                }
                HStack(spacing: 6) {
                    if let miles = station.distanceMiles {
                        Text(String(format: "%.1f mi", miles))
                            .font(FuelTrackTokens.numericFont(size: .caption))
                            .foregroundStyle(GlassTheme.accent)
                    }
                    if !station.brand.isEmpty {
                        Text("· \(station.brand)")
                    }
                    if station.isSupermarket {
                        Text("· Shop")
                    }
                    if station.is24h {
                        Text("· 24h")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text([station.address, station.city, station.postcode].filter { !$0.isEmpty }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            if let url = station.mapsURL {
                Link(destination: url) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

/// Compact price chip for map annotations — shows pence-per-litre at a glance.
private struct StationPriceMapPin: View {
    enum Style {
        case cheapest
        case favourite
        case standard

        var fill: Color {
            switch self {
            case .cheapest: GlassTheme.accent
            case .favourite: GlassTheme.accentWarm
            case .standard: Color.primary.opacity(0.75)
            }
        }
    }

    let priceLabel: String?
    let style: Style
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if let priceLabel {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(priceLabel)
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                        Text("p")
                            .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    }
                } else {
                    Text("—")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(style.fill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0.25), lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: .black.opacity(0.25), radius: isSelected ? 6 : 3, y: 2)
            .scaleEffect(isSelected ? 1.12 : 1)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(style.fill)
                .offset(y: -2)
        }
        .accessibilityLabel(priceLabel.map { "\($0) pence per litre" } ?? "Price unavailable")
    }
}

extension NearbyStation: Hashable {
    static func == (lhs: NearbyStation, rhs: NearbyStation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
