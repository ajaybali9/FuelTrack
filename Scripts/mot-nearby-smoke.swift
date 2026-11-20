#!/usr/bin/env swift
import Foundation

// Standalone smoke for GarageRegion + Haversine nearby (mirrors app helpers).
// Run: swift Scripts/mot-nearby-smoke.swift

enum GarageRegion: Equatable {
    case unitedKingdom, europe, elsewhere

    var supportsNearbyGarages: Bool { self != .elsewhere }

    static func classify(latitude: Double, longitude: Double) -> GarageRegion {
        if latitude >= 49.8 && latitude <= 60.95 && longitude >= -8.75 && longitude <= 1.85 {
            return .unitedKingdom
        }
        if latitude >= 34.5 && latitude <= 71.5 && longitude >= -25.0 && longitude <= 40.0 {
            return .europe
        }
        return .elsewhere
    }
}

struct StoredStation {
    var id: String
    var name: String
    var lat: Double
    var lon: Double
    var classes: [Int]
}

func distanceMiles(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let r = 3958.7613 // Earth radius miles
    let p1 = lat1 * .pi / 180
    let p2 = lat2 * .pi / 180
    let dphi = (lat2 - lat1) * .pi / 180
    let dlmb = (lon2 - lon1) * .pi / 180
    let a = sin(dphi / 2) * sin(dphi / 2)
        + cos(p1) * cos(p2) * sin(dlmb / 2) * sin(dlmb / 2)
    return 2 * r * asin(min(1, sqrt(a)))
}

func nearby(
    stations: [StoredStation],
    latitude: Double,
    longitude: Double,
    radiusMiles: Double,
    limit: Int
) -> [(StoredStation, Double)] {
    stations
        .filter { $0.classes.contains(4) }
        .map { ($0, distanceMiles(lat1: latitude, lon1: longitude, lat2: $0.lat, lon2: $0.lon)) }
        .filter { $0.1 <= radiusMiles }
        .sorted { $0.1 < $1.1 }
        .prefix(limit)
        .map { $0 }
}

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

// Region gate
expect(GarageRegion.classify(latitude: 53.48, longitude: -2.24) == .unitedKingdom, "Manchester is UK")
expect(GarageRegion.classify(latitude: 48.86, longitude: 2.35) == .europe, "Paris is Europe")
expect(GarageRegion.classify(latitude: 28.61, longitude: 77.21) == .elsewhere, "Delhi is elsewhere")
expect(GarageRegion.unitedKingdom.supportsNearbyGarages, "UK supported")
expect(!GarageRegion.elsewhere.supportsNearbyGarages, "elsewhere unsupported")

// Nearby filter around Sheffield sample
let stations = [
    StoredStation(id: "A", name: "Near", lat: 53.319744, lon: -1.500825, classes: [4]),
    StoredStation(id: "B", name: "Far", lat: 51.5, lon: -0.12, classes: [4]),
    StoredStation(id: "C", name: "NoClass4", lat: 53.32, lon: -1.50, classes: [7]),
]
let hits = nearby(
    stations: stations,
    latitude: 53.38,
    longitude: -1.47,
    radiusMiles: 10,
    limit: 10
)
expect(hits.count == 1, "only Class 4 within 10 mi")
expect(hits[0].0.id == "A", "nearest is A")
expect(hits[0].1 < 10, "distance under radius")

// Asset presence (optional — when run from repo root after build script)
let asset = "Sources/FuelTrack/Resources/uk-mot-stations.json"
if FileManager.default.fileExists(atPath: asset) {
    let data = try! Data(contentsOf: URL(fileURLWithPath: asset))
    expect(data.count > 1_000_000, "asset should be substantial")
    let root = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    let list = root["stations"] as! [[String: Any]]
    expect(list.count > 10_000, "thousands of Class 4 stations")
    print("Asset OK · \(list.count) stations · \(data.count) bytes")
} else {
    print("Asset not present at \(asset) — skipping file check")
}

print("mot-nearby-smoke: OK")
