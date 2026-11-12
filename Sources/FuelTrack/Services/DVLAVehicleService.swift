import Foundation
import SwiftData

struct DVLAVehicleDetails: Sendable {
    var registrationNumber: String
    var make: String?
    var colour: String?
    var fuelType: String?
    var engineCapacity: Int?
    var yearOfManufacture: Int?
    var co2Emissions: Int?
    var motStatus: String?
    var motExpiry: Date?
    var taxStatus: String?
    var taxDueDate: Date?
    var markedForExport: Bool?
    var markedAsScrapped: Bool?
}

enum DVLAVehicleError: LocalizedError {
    case missingAPIKey
    case invalidRegistration
    case http(Int, String?)
    case decoding
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your DVLA Vehicle Enquiry API key in Settings to refresh MOT & tax."
        case .invalidRegistration:
            return "Enter a valid UK registration (letters and numbers only)."
        case .http(let code, let body):
            if code == 404 { return "No vehicle found for that registration." }
            if code == 403 || code == 401 { return "DVLA API key rejected. Check it in Settings." }
            if code == 429 { return "DVLA rate limit hit. Try again in a minute." }
            return "DVLA error \(code)\(body.map { ": \($0)" } ?? "")"
        case .decoding:
            return "Could not read the DVLA response."
        case .emptyResponse:
            return "DVLA returned an empty response."
        }
    }
}

enum DVLAEnvironment: String, CaseIterable, Identifiable, Sendable {
    case test
    case production

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .test: "Test (UAT)"
        case .production: "Production"
        }
    }

    var endpoint: URL {
        switch self {
        case .test:
            URL(string: "https://uat.driver-vehicle-licensing.api.gov.uk/vehicle-enquiry/v1/vehicles")!
        case .production:
            URL(string: "https://driver-vehicle-licensing.api.gov.uk/vehicle-enquiry/v1/vehicles")!
        }
    }

    /// Official DVLA mock VRNs for the test environment.
    static let testSuccessRegistration = "AA19MOT"
}

enum DVLAVehicleService {
    static func cleanedRegistration(_ raw: String) -> String {
        raw.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    static func fetch(
        registration: String,
        apiKey: String,
        environment: DVLAEnvironment = .production
    ) async throws -> DVLAVehicleDetails {
        let cleaned = cleanedRegistration(registration)
        guard cleaned.count >= 2 else { throw DVLAVehicleError.invalidRegistration }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw DVLAVehicleError.missingAPIKey }

        var request = URLRequest(url: environment.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Correlation-Id")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "registrationNumber": cleaned
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DVLAVehicleError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw DVLAVehicleError.http(http.statusCode, body)
        }

        let decoded: APIResponse
        do {
            decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw DVLAVehicleError.decoding
        }

        return DVLAVehicleDetails(
            registrationNumber: cleanedRegistration(decoded.registrationNumber ?? cleaned),
            make: decoded.make,
            colour: decoded.colour,
            fuelType: decoded.fuelType,
            engineCapacity: decoded.engineCapacity,
            yearOfManufacture: decoded.yearOfManufacture,
            co2Emissions: decoded.co2Emissions,
            motStatus: decoded.motStatus,
            motExpiry: parseDate(decoded.motExpiryDate ?? decoded.motExpiry),
            taxStatus: decoded.taxStatus,
            taxDueDate: parseDate(decoded.taxDueDate),
            markedForExport: decoded.markedForExport,
            markedAsScrapped: decoded.markedAsScrapped
        )
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(raw.prefix(10)))
    }
}

enum VehicleComplianceSync {
    /// Upsert MOT / tax / insurance reminders from stored vehicle dates.
    @MainActor
    static func syncReminders(for vehicle: Vehicle, in context: ModelContext) {
        upsert(vehicle: vehicle, title: "MOT due", dueDate: vehicle.motExpiry, note: "MOT · \(vehicle.motStatus.isEmpty ? "expiry" : vehicle.motStatus)", in: context)
        upsert(vehicle: vehicle, title: "Road tax due", dueDate: vehicle.taxDueDate, note: "Tax · \(vehicle.taxStatus.isEmpty ? "due" : vehicle.taxStatus)", in: context)
        upsert(vehicle: vehicle, title: "Insurance renewal", dueDate: vehicle.insuranceExpiry, note: vehicle.insuranceProvider.isEmpty ? "Insurance renewal" : vehicle.insuranceProvider, in: context)
        try? context.save()
        Task {
            await ComplianceNotificationScheduler.reschedule(for: vehicle)
        }
    }

    @MainActor
    private static func upsert(
        vehicle: Vehicle,
        title: String,
        dueDate: Date?,
        note: String,
        in context: ModelContext
    ) {
        guard let dueDate else { return }
        if let existing = vehicle.reminders.first(where: { $0.title == title && !$0.isCompleted }) {
            existing.dueDate = dueDate
            existing.note = note
            return
        }
        context.insert(
            ReminderItem(
                title: title,
                dueDate: dueDate,
                note: note,
                vehicle: vehicle
            )
        )
    }
}

private struct APIResponse: Decodable {
    var registrationNumber: String?
    var make: String?
    var colour: String?
    var fuelType: String?
    var engineCapacity: Int?
    var yearOfManufacture: Int?
    var co2Emissions: Int?
    var motStatus: String?
    var motExpiry: String?
    var motExpiryDate: String?
    var taxStatus: String?
    var taxDueDate: String?
    var markedForExport: Bool?
    var markedAsScrapped: Bool?
}
