import MapKit
import SwiftUI

struct FillUpMapView: View {
    let vehicle: Vehicle

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPin: String?

    private var pins: [LogPin] {
        var items: [LogPin] = []
        for fill in vehicle.fillUps {
            guard let latitude = fill.latitude, let longitude = fill.longitude else { continue }
            let name = fill.station.trimmingCharacters(in: .whitespacesAndNewlines)
            items.append(
                LogPin(
                    id: fill.id.uuidString,
                    name: name.isEmpty ? "Fill-up" : name,
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    subtitle: Formatters.shortDate(fill.date)
                )
            )
        }
        for place in vehicle.savedStations {
            items.append(
                LogPin(
                    id: "saved-\(place.id.uuidString)",
                    name: place.name,
                    coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                    subtitle: place.note.isEmpty ? "Favourite" : place.note
                )
            )
        }
        return items
    }

    var body: some View {
        Group {
            if pins.isEmpty {
                ContentUnavailableView(
                    "No locations yet",
                    systemImage: "map",
                    description: Text("Pick a nearby station when you log a fill-up, and it will show up here.")
                )
            } else {
                Map(position: $position, selection: $selectedPin) {
                    ForEach(pins) { pin in
                        Marker(pin.name, coordinate: pin.coordinate)
                            .tint(pin.id.hasPrefix("saved-") ? GlassTheme.accentWarm : GlassTheme.accent)
                            .tag(pin.id)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapPitchToggle()
                }
                .safeAreaInset(edge: .bottom) {
                    if let selected = pins.first(where: { $0.id == selectedPin }) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selected.name)
                                    .font(.headline)
                                Text(selected.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Fill-up map")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackScreen()
    }
}

private struct LogPin: Identifiable {
    var id: String
    var name: String
    var coordinate: CLLocationCoordinate2D
    var subtitle: String
}
