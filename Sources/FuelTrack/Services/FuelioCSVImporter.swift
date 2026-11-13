import Foundation

struct FuelioImportResult: Sendable {
    var vehicleName: String
    var make: String
    var model: String
    var registrationPlate: String
    var year: Int
    var notes: String
    var odometerUnit: OdometerUnit
    var fuelType: FuelType
    var fillUps: [ImportedFillUp]
    var costs: [ImportedCost]
    var savedStations: [ImportedStation]
    var skippedRows: Int
}

struct ImportedFillUp: Sendable {
    var date: Date
    var odometer: Double
    var liters: Double
    var totalCost: Double
    var isFullTank: Bool
    var skipped: Bool
    var station: String
    var note: String
    var fuelType: FuelType?
    var latitude: Double?
    var longitude: Double?
    var stationExternalId: String
}

struct ImportedCost: Sendable {
    var title: String
    var date: Date
    var odometer: Double?
    var amount: Double
    var category: CostCategory
    var note: String
}

struct ImportedStation: Sendable {
    var name: String
    var externalId: String
    var latitude: Double
    var longitude: Double
    var note: String
}

enum FuelioImportError: LocalizedError {
    case emptyFile
    case missingVehicleSection
    case missingLogSection
    case missingVehicleRow
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .emptyFile: "The selected file is empty."
        case .missingVehicleSection: "No ## Vehicle section found. Export a CSV from Fuelio and try again."
        case .missingLogSection: "No ## Log section found. Export a CSV from Fuelio and try again."
        case .missingVehicleRow: "The Vehicle section has no data row."
        case .invalidEncoding: "Could not read the CSV as UTF-8 text."
        }
    }
}

enum FuelioCSVImporter {
    /// Parse a Fuelio-exported CSV (one vehicle + fill-up log).
    static func parse(
        data: Data,
        defaultCurrency _: CurrencyCode = .gbp
    ) throws -> FuelioImportResult {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw FuelioImportError.invalidEncoding
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FuelioImportError.emptyFile }

        let vehicleLines = try sectionLines(named: "Vehicle", in: trimmed)
        let logLines = try sectionLines(named: "Log", in: trimmed)

        guard vehicleLines.count >= 2 else { throw FuelioImportError.missingVehicleRow }
        let vehicleHeader = parseCSVRow(vehicleLines[0])
        let vehicleRow = parseCSVRow(vehicleLines[1])
        let vehicle = dictionary(header: vehicleHeader, row: vehicleRow)

        let name = vehicle["Name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { throw FuelioImportError.missingVehicleRow }

        let distUnit = Int(vehicle["DistUnit"] ?? "1") ?? 1
        var fuelUnit = Int(vehicle["FuelUnit"] ?? "2") ?? 2
        let odometerUnit: OdometerUnit = distUnit == 2 ? .kilometers : .miles
        let dateFormat = vehicle["ImportCSVDateFormat"].flatMap { $0.isEmpty ? nil : $0 } ?? "yyyy-MM-dd"
        let make = vehicle["Make"] ?? ""
        let model = vehicle["Model"] ?? ""
        let description = vehicle["Description"] ?? ""
        let plate = DVLAVehicleService.cleanedRegistration(vehicle["Plate"] ?? "")
        let year = Int(vehicle["Year"] ?? "") ?? 0
        var notesParts: [String] = []
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty { notesParts.append(trimmedDescription) }
        let tankType = Int(vehicle["Tank1Type"] ?? "0") ?? 0
        let fuelType = mapFuelType(tankType)

        guard logLines.count >= 2 else {
            return FuelioImportResult(
                vehicleName: name,
                make: make,
                model: model,
                registrationPlate: plate,
                year: year,
                notes: notesParts.joined(separator: "\n"),
                odometerUnit: odometerUnit,
                fuelType: fuelType,
                fillUps: [],
                costs: parseCosts(in: trimmed, dateFormat: dateFormat),
                savedStations: parseSavedStations(in: trimmed),
                skippedRows: 0
            )
        }

        let logHeader = parseCSVRow(logLines[0])
        // Prefer units inferred from log headers (current Fuelio exports use Date + Fuel (l)).
        fuelUnit = inferFuelUnit(from: logHeader, fallback: fuelUnit)
        var fillUps: [ImportedFillUp] = []
        var skipped = 0

        for line in logLines.dropFirst() {
            let cols = parseCSVRow(line)
            if cols.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }
            let row = dictionary(header: logHeader, row: cols)
            if let fill = parseFillUp(row: row, dateFormat: dateFormat, fuelUnit: fuelUnit) {
                fillUps.append(fill)
            } else {
                skipped += 1
            }
        }

        fillUps.sort {
            if $0.odometer != $1.odometer { return $0.odometer < $1.odometer }
            return $0.date < $1.date
        }

        return FuelioImportResult(
            vehicleName: name,
            make: make,
            model: model,
            registrationPlate: plate,
            year: year,
            notes: notesParts.joined(separator: "\n"),
            odometerUnit: odometerUnit,
            fuelType: fuelType,
            fillUps: fillUps,
            costs: parseCosts(in: trimmed, dateFormat: dateFormat),
            savedStations: parseSavedStations(in: trimmed),
            skippedRows: skipped
        )
    }

    // MARK: - Sections

    private static func sectionLines(named name: String, in text: String) throws -> [String] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let start = lines.firstIndex(where: { isSectionMarker($0, name: name) }) else {
            if name == "Vehicle" { throw FuelioImportError.missingVehicleSection }
            throw FuelioImportError.missingLogSection
        }
        var end = lines.count
        for index in (start + 1)..<lines.count {
            if isAnySectionMarker(lines[index]) {
                end = index
                break
            }
        }
        return Array(lines[(start + 1)..<end]).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func isSectionMarker(_ line: String, name: String) -> Bool {
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return cleaned.hasPrefix("## \(name)")
    }

    private static func isAnySectionMarker(_ line: String) -> Bool {
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return cleaned.hasPrefix("## ")
    }

    // MARK: - CSV helpers

    private static func dictionary(header: [String], row: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for (index, key) in header.enumerated() {
            let value = index < row.count ? row[index] : ""
            result[key] = value
        }
        return result
    }

    /// Minimal RFC4180-ish CSV row parser (quoted fields, commas).
    static func parseCSVRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let ch = line[index]
            if inQuotes {
                if ch == "\"" {
                    let next = line.index(after: index)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == "," {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
            index = line.index(after: index)
        }
        fields.append(current)
        return fields
    }

    private static func value(
        _ row: [String: String],
        matching prefixes: [String],
        allowEmpty: Bool = false
    ) -> String? {
        // Prefer exact key matches, then prefix matches (stable order by prefix list).
        for prefix in prefixes {
            for (key, value) in row {
                let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedKey == prefix {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if allowEmpty || !trimmed.isEmpty { return trimmed }
                }
            }
        }
        for prefix in prefixes {
            for (key, value) in row {
                let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedKey.hasPrefix(prefix) {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if allowEmpty || !trimmed.isEmpty { return trimmed }
                }
            }
        }
        return nil
    }

    private static func fuelAmountValue(_ row: [String: String]) -> String? {
        // Match "Fuel (l)", "Fuel (litres)", "Fuel (us gallons)" — never FuelType / FuelUnit.
        for (key, value) in row {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmedKey.lowercased()
            guard lower.hasPrefix("fuel") else { continue }
            if lower.hasPrefix("fueltype") || lower.hasPrefix("fuelunit") { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private static func inferFuelUnit(from header: [String], fallback: Int) -> Int {
        for key in header {
            let lower = key.lowercased()
            if lower.contains("fuel") && (lower.contains("(l)") || lower.contains("litre") || lower.contains("liter")) {
                return 2
            }
            if lower.contains("fuel") && lower.contains("imperial") {
                return 3
            }
            if lower.contains("fuel") && (lower.contains("us gallon") || lower.contains("(gal)")) {
                return 1
            }
        }
        // Fuelio sometimes stores FuelUnit 0 when the log is already in litres.
        return fallback == 0 ? 2 : fallback
    }

    private static func parseFillUp(
        row: [String: String],
        dateFormat: String,
        fuelUnit: Int
    ) -> ImportedFillUp? {
        // Current Fuelio iOS exports use "Date"; older samples used "Data".
        guard let dateRaw = value(row, matching: ["Date", "Data"]),
              let odoRaw = value(row, matching: ["Odo"]),
              let fuelRaw = fuelAmountValue(row),
              let odometer = Double(odoRaw.replacingOccurrences(of: ",", with: ".")),
              let fuelAmount = Double(fuelRaw.replacingOccurrences(of: ",", with: "."))
        else { return nil }

        guard let date = parseDate(dateRaw, format: dateFormat) else { return nil }
        let liters = toLiters(fuelAmount, fuelUnit: fuelUnit)
        // Prefer exact "Price" over anything that merely contains price (e.g. VolumePrice).
        let costRaw = value(row, matching: ["Price"], allowEmpty: true) ?? "0"
        let cost = Double(costRaw.replacingOccurrences(of: ",", with: ".")) ?? 0
        let fullRaw = value(row, matching: ["Full"], allowEmpty: true) ?? "1"
        let missedRaw = value(row, matching: ["Missed"], allowEmpty: true) ?? "0"
        let station = value(row, matching: ["City"], allowEmpty: true) ?? ""
        let note = value(row, matching: ["Notes"], allowEmpty: true) ?? ""
        let latitude = doubleValue(row, matching: ["latitude", "Latitude"])
        let longitude = doubleValue(row, matching: ["longitude", "Longitude"])
        let stationId = value(row, matching: ["StationID"], allowEmpty: true) ?? ""
        let rowFuel = value(row, matching: ["FuelType"], allowEmpty: true).flatMap(Int.init).map(mapFuelType)

        return ImportedFillUp(
            date: date,
            odometer: odometer,
            liters: liters,
            totalCost: cost,
            isFullTank: fullRaw == "1" || fullRaw.lowercased() == "true",
            skipped: missedRaw == "1" || missedRaw.lowercased() == "true",
            station: station,
            note: note,
            fuelType: rowFuel,
            latitude: latitude,
            longitude: longitude,
            stationExternalId: stationId == "0" ? "" : stationId
        )
    }

    private static func doubleValue(_ row: [String: String], matching prefixes: [String]) -> Double? {
        guard let raw = value(row, matching: prefixes, allowEmpty: true) else { return nil }
        return Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    /// Fuelio FuelUnit: 0/2 = litre, 1 = US gallon, 3 = Imperial gallon.
    private static func toLiters(_ amount: Double, fuelUnit: Int) -> Double {
        switch fuelUnit {
        case 1: amount * 3.785411784
        case 3: amount * 4.54609
        default: amount
        }
    }

    private static func parseDate(_ raw: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        let candidates = [
            format + " HH:mm",
            format + " HH:mm:ss",
            format,
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "MM/dd/yyyy",
        ]

        for pattern in candidates {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    static func mapFuelType(_ tankType: Int) -> FuelType {
        switch tankType {
        case 800: .other
        case 700: .hybrid
        case 112, 113, 114: .petrolE5
        case 100..<200: .petrolE10
        case 202, 209, 211, 218, 219: .dieselPremium
        case 200..<300: .diesel
        case 400..<500: .lpg
        case 600..<700: .electric
        default: .petrolE10
        }
    }

    private static func optionalSectionLines(named name: String, in text: String) -> [String] {
        (try? sectionLines(named: name, in: text)) ?? []
    }

    private static func parseCosts(in text: String, dateFormat: String) -> [ImportedCost] {
        let namesByID = categoryNames(in: text)
        let lines = optionalSectionLines(named: "Costs", in: text)
        guard lines.count >= 2 else { return [] }
        let header = parseCSVRow(lines[0])
        var costs: [ImportedCost] = []
        for line in lines.dropFirst() {
            let row = dictionary(header: header, row: parseCSVRow(line))
            guard let title = value(row, matching: ["CostTitle"]),
                  let dateRaw = value(row, matching: ["Date"]),
                  let date = parseDate(dateRaw, format: dateFormat),
                  let amountRaw = value(row, matching: ["Cost"]),
                  let amount = Double(amountRaw.replacingOccurrences(of: ",", with: "."))
            else { continue }
            let odoRaw = value(row, matching: ["Odo"], allowEmpty: true) ?? ""
            let odometer = Double(odoRaw.replacingOccurrences(of: ",", with: "."))
            let typeID = value(row, matching: ["CostTypeID"], allowEmpty: true) ?? ""
            let categoryName = namesByID[typeID] ?? typeID
            let note = value(row, matching: ["Notes"], allowEmpty: true) ?? ""
            costs.append(
                ImportedCost(
                    title: title,
                    date: date,
                    odometer: odometer,
                    amount: amount,
                    category: CostCategory.fromFuelioName(categoryName),
                    note: note
                )
            )
        }
        return costs
    }

    private static func categoryNames(in text: String) -> [String: String] {
        let lines = optionalSectionLines(named: "CostCategories", in: text)
        guard lines.count >= 2 else { return [:] }
        let header = parseCSVRow(lines[0])
        var names: [String: String] = [:]
        for line in lines.dropFirst() {
            let row = dictionary(header: header, row: parseCSVRow(line))
            guard let id = row["CostTypeID"], let name = row["Name"], !name.isEmpty else { continue }
            names[id] = name
        }
        return names
    }

    private static func parseSavedStations(in text: String) -> [ImportedStation] {
        let lines = optionalSectionLines(named: "FavStations", in: text)
        guard lines.count >= 2 else { return [] }
        let header = parseCSVRow(lines[0])
        var stations: [ImportedStation] = []
        for line in lines.dropFirst() {
            let row = dictionary(header: header, row: parseCSVRow(line))
            guard let name = value(row, matching: ["Name"]),
                  let latitude = doubleValue(row, matching: ["Latitude"]),
                  let longitude = doubleValue(row, matching: ["Longitude"])
            else { continue }
            let external = value(row, matching: ["StationId", "StationID"], allowEmpty: true) ?? ""
            let note = value(row, matching: ["Description"], allowEmpty: true) ?? ""
            stations.append(
                ImportedStation(
                    name: name,
                    externalId: external,
                    latitude: latitude,
                    longitude: longitude,
                    note: note
                )
            )
        }
        return stations
    }
}
