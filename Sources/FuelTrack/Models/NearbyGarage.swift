import CoreLocation
import Foundation

enum NearbyGarageKind: String, CaseIterable, Identifiable, Sendable, CustomStringConvertible {
    case mot
    case repair

    var id: String { rawValue }

    var description: String {
        switch self {
        case .mot: "MOT"
        case .repair: "Repair"
        }
    }

    var systemImage: String {
        switch self {
        case .mot: "checklist"
        case .repair: "wrench.and.screwdriver"
        }
    }
}

enum NearbyGarageSource: String, Sendable {
    case dvsa
    case mapKit
}

enum NearbyGarageFilter: String, CaseIterable, Identifiable, Hashable, Sendable, CustomStringConvertible {
    case all
    case mot
    case repair

    var id: String { rawValue }

    var description: String {
        switch self {
        case .all: "All"
        case .mot: "MOT"
        case .repair: "Repair"
        }
    }
}

struct NearbyGarage: Identifiable, Sendable, Hashable {
    var id: String
    var name: String
    var address: String
    var town: String
    var postcode: String
    var phone: String
    var coordinate: CLLocationCoordinate2D
    var distanceMiles: Double?
    var kinds: Set<NearbyGarageKind>
    var motClasses: [Int]
    var source: NearbyGarageSource

    var displayAddress: String {
        [address, town, postcode]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var mapsURL: URL? {
        URL(string: "http://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)")
    }

    var phoneURL: URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    var sourceLabel: String {
        switch source {
        case .dvsa: "DVSA register"
        case .mapKit: "Apple Maps"
        }
    }

    static func == (lhs: NearbyGarage, rhs: NearbyGarage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
