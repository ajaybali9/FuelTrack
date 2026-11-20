import CoreLocation
import Foundation
import MapKit

enum NearbyGaragesError: LocalizedError {
    case locationUnavailable
    case regionUnsupported(GarageRegion)
    case mapKit(String)

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Waiting for a GPS fix to find nearby garages."
        case .regionUnsupported(let region):
            return region.unavailableMessage
        case .mapKit(let message):
            return message
        }
    }
}

struct NearbyGaragesResponse: Sendable {
    var garages: [NearbyGarage]
    var region: GarageRegion
    var registerBuiltAt: String?
}

enum NearbyGaragesService {
    static func fetch(
        latitude: Double,
        longitude: Double,
        filter: NearbyGarageFilter = .all,
        radiusMiles: Int = 10,
        limit: Int = 40
    ) async throws -> NearbyGaragesResponse {
        let region = GarageRegion.classify(latitude: latitude, longitude: longitude)
        guard region.supportsNearbyGarages else {
            throw NearbyGaragesError.regionUnsupported(region)
        }

        var results: [NearbyGarage] = []

        switch filter {
        case .mot:
            if region.usesDVSA {
                results = UKMOTStationsStore.nearby(
                    latitude: latitude,
                    longitude: longitude,
                    radiusMiles: Double(radiusMiles),
                    limit: limit
                )
                // NI / sparse DVSA cells: fall back to MapKit inspection search.
                if results.isEmpty {
                    results = try await mapKitGarages(
                        latitude: latitude,
                        longitude: longitude,
                        radiusMiles: radiusMiles,
                        limit: limit,
                        mode: .mot
                    )
                }
            } else {
                results = try await mapKitGarages(
                    latitude: latitude,
                    longitude: longitude,
                    radiusMiles: radiusMiles,
                    limit: limit,
                    mode: .mot
                )
            }

        case .repair:
            results = try await mapKitGarages(
                latitude: latitude,
                longitude: longitude,
                radiusMiles: radiusMiles,
                limit: limit,
                mode: .repair
            )

        case .all:
            var merged: [NearbyGarage] = []
            if region.usesDVSA {
                merged.append(
                    contentsOf: UKMOTStationsStore.nearby(
                        latitude: latitude,
                        longitude: longitude,
                        radiusMiles: Double(radiusMiles),
                        limit: limit
                    )
                )
            }
            let repairs = try await mapKitGarages(
                latitude: latitude,
                longitude: longitude,
                radiusMiles: radiusMiles,
                limit: limit,
                mode: region.usesDVSA ? .repair : .all
            )
            for item in repairs {
                if let index = merged.firstIndex(where: { isLikelySame($0, item) }) {
                    var existing = merged[index]
                    existing.kinds.formUnion(item.kinds)
                    if existing.phone.isEmpty { existing.phone = item.phone }
                    if existing.address.isEmpty { existing.address = item.address }
                    merged[index] = existing
                } else {
                    merged.append(item)
                }
            }
            results = merged
        }

        results.sort {
            ($0.distanceMiles ?? .greatestFiniteMagnitude) < ($1.distanceMiles ?? .greatestFiniteMagnitude)
        }

        return NearbyGaragesResponse(
            garages: Array(results.prefix(limit)),
            region: region,
            registerBuiltAt: UKMOTStationsStore.registerBuiltAt
        )
    }

    private enum MapMode {
        case mot
        case repair
        case all
    }

    private static func mapKitGarages(
        latitude: Double,
        longitude: Double,
        radiusMiles: Int,
        limit: Int,
        mode: MapMode
    ) async throws -> [NearbyGarage] {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let meters = Double(radiusMiles) * 1609.344
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: meters * 2,
            longitudinalMeters: meters * 2
        )

        var items: [MKMapItem] = []

        switch mode {
        case .repair, .all:
            items += try await searchMapItems(
                query: "car repair",
                region: region,
                including: [.automotiveRepair]
            )
        case .mot:
            break
        }

        if mode == .mot || mode == .all {
            let motItems = try await searchMapItems(
                query: "MOT test centre",
                region: region,
                including: [.automotiveRepair]
            )
            items.append(contentsOf: motItems)
        }

        let origin = CLLocation(latitude: latitude, longitude: longitude)
        var seen = Set<String>()
        var garages: [NearbyGarage] = []

        for item in items {
            let coordinate = item.location.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate) else { continue }

            let miles = origin.distance(from: item.location) / 1609.344
            guard miles <= Double(radiusMiles) + 0.15 else { continue }

            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let name, !name.isEmpty else { continue }

            let id = mapKitID(item: item, coordinate: coordinate)
            guard seen.insert(id).inserted else { continue }

            let kinds: Set<NearbyGarageKind>
            switch mode {
            case .mot: kinds = [.mot]
            case .repair: kinds = [.repair]
            case .all:
                kinds = nameLocalizedSuggestsMOT(name) ? [.mot, .repair] : [.repair]
            }

            let fullAddress = item.address?.fullAddress?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let shortAddress = item.address?.shortAddress?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let town = item.addressRepresentations?.cityName?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            garages.append(
                NearbyGarage(
                    id: id,
                    name: name,
                    address: shortAddress.isEmpty ? fullAddress : shortAddress,
                    town: town,
                    postcode: "",
                    phone: item.phoneNumber ?? "",
                    coordinate: coordinate,
                    distanceMiles: miles,
                    kinds: kinds,
                    motClasses: [],
                    source: .mapKit
                )
            )
        }

        garages.sort {
            ($0.distanceMiles ?? .greatestFiniteMagnitude) < ($1.distanceMiles ?? .greatestFiniteMagnitude)
        }
        return Array(garages.prefix(limit))
    }

    private static func searchMapItems(
        query: String,
        region: MKCoordinateRegion,
        including categories: [MKPointOfInterestCategory]
    ) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest
        if #available(iOS 18.0, macOS 15.0, *) {
            request.regionPriority = .required
        }
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems
        } catch {
            // Soft-fail individual searches so DVSA-only results still show.
            return []
        }
    }

    private static func mapKitID(item: MKMapItem, coordinate: CLLocationCoordinate2D) -> String {
        if let id = item.identifier?.rawValue, !id.isEmpty {
            return "mk-\(id)"
        }
        let lat = String(format: "%.5f", coordinate.latitude)
        let lon = String(format: "%.5f", coordinate.longitude)
        let name = (item.name ?? "place").lowercased()
        return "mk-\(name)-\(lat)-\(lon)"
    }

    private static func nameLocalizedSuggestsMOT(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return lowered.contains("mot") || lowered.contains("vehicle test") || lowered.contains("test centre")
    }

    private static func isLikelySame(_ a: NearbyGarage, _ b: NearbyGarage) -> Bool {
        let aLoc = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude)
        let bLoc = CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude)
        guard aLoc.distance(from: bLoc) <= 75 else { return false }
        if !a.postcode.isEmpty, !b.postcode.isEmpty {
            let ap = a.postcode.replacingOccurrences(of: " ", with: "").uppercased()
            let bp = b.postcode.replacingOccurrences(of: " ", with: "").uppercased()
            if ap == bp { return true }
        }
        return normalizedName(a.name) == normalizedName(b.name)
    }

    private static func normalizedName(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .filter { $0.isLetter || $0.isNumber }
    }
}
