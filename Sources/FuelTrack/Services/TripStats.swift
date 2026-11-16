import CoreLocation
import Foundation

enum TripStats {
    static let minimumHorizontalAccuracyMeters: Double = 50
    static let maximumJumpMeters: Double = 200

    static func haversineMeters(
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) -> Double {
        let r = 6_371_000.0
        let φ1 = a.latitude * .pi / 180
        let φ2 = b.latitude * .pi / 180
        let Δφ = (b.latitude - a.latitude) * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let sinΔφ = sin(Δφ / 2)
        let sinΔλ = sin(Δλ / 2)
        let h = sinΔφ * sinΔφ + cos(φ1) * cos(φ2) * sinΔλ * sinΔλ
        return 2 * r * atan2(sqrt(h), sqrt(1 - h))
    }

    static func shouldAccept(
        location: CLLocation,
        previous: CLLocation?
    ) -> Bool {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= minimumHorizontalAccuracyMeters
        else { return false }
        guard let previous else { return true }
        let jump = location.distance(from: previous)
        return jump <= maximumJumpMeters
    }

    static func distanceInUnit(metres: Double, unit: OdometerUnit) -> Double {
        unit.fromKilometers(metres / 1000)
    }

    /// Convert m/s to miles-per-hour or km-per-hour.
    static func speedInUnit(metersPerSecond: Double, unit: OdometerUnit) -> Double {
        let kmh = metersPerSecond * 3.6
        return unit.fromKilometers(kmh)
    }

    static func averageSpeed(distance: Double, durationSeconds: Double) -> Double {
        guard durationSeconds > 0 else { return 0 }
        return distance / (durationSeconds / 3600)
    }

    static func durationSeconds(startedAt: Date, endedAt: Date) -> Double {
        max(0, endedAt.timeIntervalSince(startedAt))
    }

    /// Snapshot vehicle FuelStats averages onto the trip (estimate, not GPS-derived burn).
    static func estimatedEconomy(
        averageMPG: Double?,
        averageLitersPer100km: Double?
    ) -> (mpg: Double?, litersPer100km: Double?) {
        (averageMPG, averageLitersPer100km)
    }
}