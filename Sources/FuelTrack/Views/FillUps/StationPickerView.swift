import SwiftData
import SwiftUI

struct StationPickerView: View {
    let fuelType: FuelType
    var onSelectNearby: (NearbyStation) -> Void
    var onSelectName: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(LocationProvider.self) private var locationProvider
    @Query(sort: \FillUp.date, order: .reverse) private var fillUps: [FillUp]

    @State private var stations: [NearbyStation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var search = ""
    @State private var sortCheapest = false
    @State private var radiusMiles = 20

    init(
        fuelType: FuelType,
        onSelect: @escaping (NearbyStation) -> Void,
        onSelectName: ((String) -> Void)? = nil
    ) {
        self.fuelType = fuelType
        self.onSelectNearby = onSelect
        self.onSelectName = onSelectName
    }

    private var usedStations: [UsedStationSummary] {
        UsedStations.summarize(from: fillUps)
    }

    private var filteredUsed: [UsedStationSummary] {
        usedStations.filter { StationSearch.matchesUsed($0, query: search) }
    }

    private var filteredNearby: [NearbyStation] {
        let matched = stations.filter { StationSearch.matches($0, query: search) }
        if sortCheapest {
            return matched.sorted {
                ($0.pricePence ?? .greatestFiniteMagnitude) < ($1.pricePence ?? .greatestFiniteMagnitude)
            }
        }
        return matched.sorted {
            ($0.distanceMiles ?? .greatestFiniteMagnitude) < ($1.distanceMiles ?? .greatestFiniteMagnitude)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && stations.isEmpty && usedStations.isEmpty {
                    ProgressView("Loading stations…")
                } else if let errorMessage, stations.isEmpty, filteredUsed.isEmpty {
                    ContentUnavailableView(
                        "Couldn't load stations",
                        systemImage: "mappin.slash",
                        description: Text(errorMessage)
                    )
                } else if filteredNearby.isEmpty && filteredUsed.isEmpty {
                    ContentUnavailableView(
                        search.isEmpty ? "No stations" : "No matches",
                        systemImage: "fuelpump",
                        description: Text(
                            search.isEmpty
                                ? "Widen the radius or refresh."
                                : "Nothing matched “\(search)”. Try “Tesco” or a postcode, or widen the radius."
                        )
                    )
                } else {
                    List {
                        if !filteredUsed.isEmpty {
                            Section("From your fuel logs") {
                                ForEach(filteredUsed) { used in
                                    Button {
                                        selectUsed(used)
                                    } label: {
                                        usedRow(used)
                                    }
                                }
                            }
                        }

                        Section {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                    Text("Updating nearby…")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            ForEach(filteredNearby) { station in
                                Button {
                                    onSelectNearby(station)
                                    dismiss()
                                } label: {
                                    nearbyRow(station)
                                }
                            }
                        } header: {
                            Text(
                                filteredNearby.isEmpty
                                    ? "Nearby"
                                    : "Nearby · \(filteredNearby.count) · \(sortCheapest ? "cheapest" : "nearest")"
                            )
                        } footer: {
                            Text("Search matches name, brand, town and postcode. Radius \(radiusMiles) mi.")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Choose station")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "e.g. Tesco Basingstoke")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Radius", selection: $radiusMiles) {
                            Text("10 miles").tag(10)
                            Text("20 miles").tag(20)
                            Text("30 miles").tag(30)
                        }
                        Divider()
                        Button("Sort by nearest") { sortCheapest = false }
                        Button("Sort by cheapest") { sortCheapest = true }
                        Button("Refresh") { Task { await load(force: true) } }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { await load(force: false) }
            .onChange(of: radiusMiles) { _, _ in
                Task { await load(force: false) }
            }
        }
    }

    private func usedRow(_ used: UsedStationSummary) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "star.fill")
                .foregroundStyle(GlassTheme.accentWarm)
            VStack(alignment: .leading, spacing: 4) {
                Text(used.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text("\(used.visitCount)×")
                    Text("· last \(Formatters.shortDate(used.lastVisit))")
                    if let nearby = UsedStations.bestMatch(for: used, in: stations),
                       let price = nearby.pricePence {
                        Text("·")
                        Text(String(format: "%.1fp now", price))
                            .foregroundStyle(GlassTheme.accent)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(GlassTheme.accent)
        }
    }

    private func nearbyRow(_ station: NearbyStation) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    if let price = station.pricePence {
                        Text(String(format: "%.1fp/L", price))
                            .fontWeight(.semibold)
                    }
                    if let miles = station.distanceMiles {
                        Text("· \(String(format: "%.1f mi", miles))")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text([station.brand, station.city, station.postcode].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(GlassTheme.accent)
        }
    }

    private func selectUsed(_ used: UsedStationSummary) {
        if let nearby = UsedStations.bestMatch(for: used, in: stations) {
            onSelectNearby(nearby)
        } else if let onSelectName {
            onSelectName(used.displayName)
        } else {
            onSelectNearby(
                NearbyStation(
                    id: "used-\(used.id)",
                    name: used.displayName,
                    brand: "",
                    address: "",
                    city: "",
                    postcode: "",
                    coordinate: .init(latitude: 0, longitude: 0),
                    pricePence: nil,
                    allPrices: [:],
                    distanceMiles: nil,
                    updatedAt: nil,
                    isSupermarket: false,
                    is24h: false
                )
            )
        }
        dismiss()
    }

    @MainActor
    private func load(force: Bool) async {
        let code = fuelType.nearbyAPIFuelCode ?? "E10"
        if force || locationProvider.coordinate == nil {
            locationProvider.requestAccessIfNeeded()
            locationProvider.refresh()
            // Wait longer — sheet often opens before the first GPS fix.
            for _ in 0..<6 {
                if locationProvider.coordinate != nil { break }
                try? await Task.sleep(nanoseconds: 400_000_000)
                locationProvider.refresh()
            }
        }
        guard let coordinate = locationProvider.coordinate else {
            errorMessage = locationProvider.isAuthorized
                ? (locationProvider.lastError ?? "Waiting for location… Pull refresh from the menu.")
                : "Enable Location to list nearby stations."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await NearbyStationsService.fetch(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                fuelCode: code,
                radiusMiles: radiusMiles,
                limit: 100
            )
            stations = response.stations
            if stations.isEmpty {
                errorMessage = "No stations in \(radiusMiles) mi. Try a wider radius."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
