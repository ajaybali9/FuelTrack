import CoreLocation
import Foundation

/// On-device DVSA Active MOT stations (Class 4+), geocoded offline into a bundled JSON asset.
enum UKMOTStationsStore {
    private static let assetName = "uk-mot-stations"
    private static let metaName = "uk-mot-stations.meta"

    private static let lock = NSLock()
    private nonisolated(unsafe) static var cachedStations: [StoredStation]?
    private nonisolated(unsafe) static var cachedMeta: Meta?

    struct Meta: Decodable, Sendable {
        var source: String?
        var sourceURL: String?
        var licence: String?
        var builtAt: String?
        var stationCount: Int?
        var filter: String?
    }

    private struct Root: Decodable {
        var stations: [StoredStation]
    }

    struct StoredStation: Decodable, Sendable {
        var id: String
        var name: String
        var address: String
        var town: String
        var postcode: String
        var phone: String
        var lat: Double
        var lon: Double
        var classes: [Int]

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    static var registerBuiltAt: String? {
        loadMeta()?.builtAt
    }

    static var stationCount: Int {
        loadStations().count
    }

    static func nearby(
        latitude: Double,
        longitude: Double,
        radiusMiles: Double,
        limit: Int = 40,
        requireClass4: Bool = true
    ) -> [NearbyGarage] {
        let origin = CLLocation(latitude: latitude, longitude: longitude)
        let radiusMeters = radiusMiles * 1609.344

        var scored: [(NearbyGarage, Double)] = []
        scored.reserveCapacity(min(limit * 4, 256))

        for station in loadStations() {
            if requireClass4, !station.classes.contains(4) { continue }
            let location = CLLocation(latitude: station.lat, longitude: station.lon)
            let meters = origin.distance(from: location)
            guard meters <= radiusMeters else { continue }
            let miles = meters / 1609.344
            let garage = NearbyGarage(
                id: "dvsa-\(station.id)",
                name: station.name,
                address: station.address,
                town: station.town,
                postcode: station.postcode,
                phone: station.phone,
                coordinate: station.coordinate,
                distanceMiles: miles,
                kinds: [.mot],
                motClasses: station.classes.sorted(),
                source: .dvsa
            )
            scored.append((garage, miles))
        }

        scored.sort { $0.1 < $1.1 }
        return scored.prefix(limit).map(\.0)
    }

    static func loadStations() -> [StoredStation] {
        lock.lock()
        defer { lock.unlock() }
        if let cachedStations { return cachedStations }
        let stations = decodeStations()
        cachedStations = stations
        return stations
    }

    static func loadMeta() -> Meta? {
        lock.lock()
        defer { lock.unlock() }
        if let cachedMeta { return cachedMeta }
        let meta = decodeMeta()
        cachedMeta = meta
        return meta
    }

    /// Test seam — inject stations without Bundle resources.
    static func replaceCacheForTesting(_ stations: [StoredStation], meta: Meta? = nil) {
        lock.lock()
        defer { lock.unlock() }
        cachedStations = stations
        cachedMeta = meta
    }

    static func resetCacheForTesting() {
        lock.lock()
        defer { lock.unlock() }
        cachedStations = nil
        cachedMeta = nil
    }

    private static func decodeStations() -> [StoredStation] {
        guard let url = Bundle.module.url(forResource: assetName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(Root.self, from: data)
        else {
            return []
        }
        return root.stations
    }

    private static func decodeMeta() -> Meta? {
        guard let url = Bundle.module.url(forResource: metaName, withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return try? JSONDecoder().decode(Meta.self, from: data)
    }
}
