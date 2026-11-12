import Foundation
import SwiftData

@Model
final class CarCost {
    var id: UUID
    var title: String
    var date: Date
    var odometer: Double?
    var amount: Double
    var currencyCodeRaw: String
    var categoryRaw: String
    var note: String
    var createdAt: Date

    var vehicle: Vehicle?

    init(
        id: UUID = UUID(),
        title: String,
        date: Date = .now,
        odometer: Double? = nil,
        amount: Double,
        currencyCode: CurrencyCode = .gbp,
        category: CostCategory = .service,
        categoryKey: String? = nil,
        note: String = "",
        createdAt: Date = .now,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.odometer = odometer
        self.amount = amount
        self.currencyCodeRaw = currencyCode.rawValue
        self.categoryRaw = categoryKey ?? category.rawValue
        self.note = note
        self.createdAt = createdAt
        self.vehicle = vehicle
    }

    var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) ?? .gbp }
        set { currencyCodeRaw = newValue.rawValue }
    }

    var categoryKey: String {
        get { categoryRaw }
        set { categoryRaw = newValue }
    }

    var category: CostCategory {
        get { CostCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
