import Foundation

enum Formatters {
    static func currency(_ value: Double, code: CurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code.rawValue
        formatter.locale = Locale(identifier: code.localeIdentifier)
        return formatter.string(from: NSNumber(value: value)) ?? "\(code.symbol)\(String(format: "%.2f", value))"
    }

    static func liters(_ value: Double) -> String {
        String(format: "%.2f L", value)
    }

    static func odometer(_ value: Double, unit: OdometerUnit) -> String {
        String(format: "%.1f %@", value, unit.shortLabel)
    }

    static func consumptionL100(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f L/100km", value)
    }

    static func consumptionMPG(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f MPG", value)
    }

    static func costPerDistance(_ value: Double?, unit: OdometerUnit, code: CurrencyCode) -> String {
        guard let value else { return "—" }
        return "\(currency(value, code: code))/\(unit.shortLabel)"
    }

    static func pricePerLiter(_ value: Double?, code: CurrencyCode) -> String {
        guard let value else { return "—" }
        return "\(currency(value, code: code))/L"
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
