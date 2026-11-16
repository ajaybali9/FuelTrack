#!/usr/bin/env swift
import Foundation

enum OdometerUnit {
    case miles, kilometers
    func fromKilometers(_ kilometers: Double) -> Double {
        switch self {
        case .miles: kilometers / 1.609344
        case .kilometers: kilometers
        }
    }
}

struct Sample {
    var latitude: Double
    var longitude: Double
    var recordedAt: Date
    var speedMps: Double?
}

func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let r = 6_371_000.0
    let φ1 = lat1 * .pi / 180
    let φ2 = lat2 * .pi / 180
    let Δφ = (lat2 - lat1) * .pi / 180
    let Δλ = (lon2 - lon1) * .pi / 180
    let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
    return 2 * r * atan2(sqrt(a), sqrt(1 - a))
}

func distanceMeters(_ samples: [Sample]) -> Double {
    guard samples.count >= 2 else { return 0 }
    var total = 0.0
    for i in 1..<samples.count {
        total += haversineMeters(
            lat1: samples[i - 1].latitude, lon1: samples[i - 1].longitude,
            lat2: samples[i].latitude, lon2: samples[i].longitude
        )
    }
    return total
}

func durationSeconds(from samples: [Sample], endedAt: Date? = nil) -> Double {
    guard let first = samples.first else { return 0 }
    let end = endedAt ?? samples.last?.recordedAt ?? first.recordedAt
    return max(0, end.timeIntervalSince(first.recordedAt))
}

func averageSpeed(distance: Double, durationSeconds: Double) -> Double {
    guard durationSeconds > 0 else { return 0 }
    return distance / (durationSeconds / 3600)
}

/// metres/sec → mi/h or km/h (numeric km/h treated as km magnitude for unit conversion).
func speedInUnit(mps: Double, unit: OdometerUnit) -> Double {
    let kmh = mps * 3.6
    return unit.fromKilometers(kmh)
}

func estimatedEconomy(averageMPG: Double?, averageL100: Double?) -> (mpg: Double?, l100: Double?) {
    (averageMPG, averageL100)
}

let t0 = Date(timeIntervalSince1970: 1_700_000_000)
let samples = [
    Sample(latitude: 51.5074, longitude: -0.1278, recordedAt: t0, speedMps: 10),
    Sample(latitude: 51.5174, longitude: -0.1278, recordedAt: t0.addingTimeInterval(600), speedMps: 20),
]
let metres = distanceMeters(samples)
assert(metres > 1000 && metres < 1200) // ~1.11 km north
let unit = OdometerUnit.miles
let distance = unit.fromKilometers(metres / 1000)
let duration = durationSeconds(from: samples)
assert(abs(duration - 600) < 0.001)
let avg = averageSpeed(distance: distance, durationSeconds: duration)
assert(avg > 0)
let maxS = samples.compactMap(\.speedMps).map { speedInUnit(mps: $0, unit: unit) }.max()!
assert(abs(maxS - speedInUnit(mps: 20, unit: .miles)) < 0.001)
let eco = estimatedEconomy(averageMPG: 40, averageL100: 7.0)
assert(eco.mpg == 40 && eco.l100 == 7.0)
print("tripstats-smoke: PASS (metres=\(Int(metres)), avgMph=\(String(format: "%.1f", avg)))")