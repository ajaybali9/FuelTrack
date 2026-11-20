import CoreLocation
import Foundation

/// Coarse region gate for Nearby Garages (UK-first, Europe supported).
enum GarageRegion: String, Sendable {
    case unitedKingdom
    case europe
    case elsewhere

    var supportsNearbyGarages: Bool {
        self != .elsewhere
    }

    var usesDVSA: Bool {
        self == .unitedKingdom
    }

    var unavailableMessage: String {
        "Nearby garages currently covers the UK and Europe. Open the feature again when you’re in that region."
    }

    /// Bounding-box classifier — good enough for feature gating without a network reverse-geocode.
    static func classify(latitude: Double, longitude: Double) -> GarageRegion {
        if isUnitedKingdom(latitude: latitude, longitude: longitude) {
            return .unitedKingdom
        }
        if isEurope(latitude: latitude, longitude: longitude) {
            return .europe
        }
        return .elsewhere
    }

    static func classify(_ coordinate: CLLocationCoordinate2D) -> GarageRegion {
        classify(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// Great Britain + Northern Ireland approximate bounds.
    private static func isUnitedKingdom(latitude: Double, longitude: Double) -> Bool {
        latitude >= 49.8 && latitude <= 60.95 && longitude >= -8.75 && longitude <= 1.85
    }

    /// Broad Europe incl. Ireland / Iberia / Nordics / Balkans (excludes most of Russia/Asia).
    private static func isEurope(latitude: Double, longitude: Double) -> Bool {
        latitude >= 34.5 && latitude <= 71.5 && longitude >= -25.0 && longitude <= 40.0
    }
}
