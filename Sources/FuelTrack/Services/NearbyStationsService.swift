import CoreLocation
import Foundation

struct NearbyStation: Identifiable, Sendable {
    var id: String
    var name: String
    var brand: String
    var address: String
    var city: String
    var postcode: String
    var coordinate: CLLocationCoordinate2D
    var pricePence: Double?
    var allPrices: [String: Double]
    var distanceMiles: Double?
    var updatedAt: Date?
    var isSupermarket: Bool
    var is24h: Bool

    var mapsURL: URL? {
        URL(string: "http://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)")
    }
}

struct NearbyStationsResponse: Sendable {
    var stations: [NearbyStation]
    var lastUpdated: Date?
    var fuelCode: String
}

enum NearbyStationsError: LocalizedError {
    case invalidURL
    case badResponse
    case decoding
    case http(Int)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not build the stations request."
        case .badResponse: return "Unexpected response from the fuel price service."
        case .decoding: return "Could not read station prices."
        case .http(let code): return "Fuel price service returned HTTP \(code)."
        case .message(let text): return text
        }
    }
}

enum NearbyStationsService {
    private static let baseURL = URL(string: "https://cheapestfuelnearme.co.uk/api/stations")!

    static func fetch(
        latitude: Double,
        longitude: Double,
        fuelCode: String,
        radiusMiles: Int = 10,
        limit: Int = 25
    ) async throws -> NearbyStationsResponse {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "fuel", value: fuelCode),
            URLQueryItem(name: "radius", value: String(radiusMiles)),
            URLQueryItem(name: "unit", value: "mi"),
            URLQueryItem(name: "sort", value: "cheapest"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components?.url else { throw NearbyStationsError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("FuelTrack/1.1 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NearbyStationsError.badResponse }
        guard (200..<300).contains(http.statusCode) else { throw NearbyStationsError.http(http.statusCode) }

        let decoded: APIRoot
        do {
            decoded = try JSONDecoder().decode(APIRoot.self, from: data)
        } catch {
            throw NearbyStationsError.decoding
        }

        let stations = decoded.stations.map { item -> NearbyStation in
            NearbyStation(
                id: item.id,
                name: item.displayName ?? item.name,
                brand: item.brand ?? "",
                address: item.address ?? "",
                city: item.city ?? "",
                postcode: item.postcode ?? "",
                coordinate: CLLocationCoordinate2D(latitude: item.lat, longitude: item.lon),
                pricePence: item.price,
                allPrices: item.prices ?? [:],
                distanceMiles: item.distance,
                updatedAt: parseISO(item.updated?[fuelCode]),
                isSupermarket: item.supermarket ?? false,
                is24h: item.is24h ?? false
            )
        }

        return NearbyStationsResponse(
            stations: stations,
            lastUpdated: parseISO(decoded.lastUpdated),
            fuelCode: fuelCode
        )
    }

    private static func parseISO(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}

private struct APIRoot: Decodable {
    var lastUpdated: String?
    var stations: [APIStation]
}

private struct APIStation: Decodable {
    var id: String
    var name: String
    var displayName: String?
    var brand: String?
    var address: String?
    var city: String?
    var postcode: String?
    var lat: Double
    var lon: Double
    var is24h: Bool?
    var supermarket: Bool?
    var prices: [String: Double]?
    var updated: [String: String]?
    var price: Double?
    var distance: Double?
}
