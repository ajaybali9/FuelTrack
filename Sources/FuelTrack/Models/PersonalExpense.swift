import Foundation
import SwiftData

@Model
final class PersonalExpense {
    var id: UUID
    var title: String
    var date: Date
    var amount: Double
    var currencyCodeRaw: String
    var categoryRaw: String
    var note: String
    var paymentMethod: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        date: Date = .now,
        amount: Double,
        currencyCode: CurrencyCode = .gbp,
        category: PersonalExpenseCategory = .other,
        note: String = "",
        paymentMethod: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.amount = amount
        self.currencyCodeRaw = currencyCode.rawValue
        self.categoryRaw = category.rawValue
        self.note = note
        self.paymentMethod = paymentMethod
        self.createdAt = createdAt
    }

    var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) ?? .gbp }
        set { currencyCodeRaw = newValue.rawValue }
    }

    var categoryKey: String {
        get { categoryRaw }
        set { categoryRaw = newValue }
    }

    var category: PersonalExpenseCategory {
        get { PersonalExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
final class PersonalBudget {
    var id: UUID
    var categoryRaw: String
    /// Empty categoryRaw means overall monthly budget.
    var monthlyLimit: Double
    var currencyCodeRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        category: PersonalExpenseCategory? = nil,
        monthlyLimit: Double,
        currencyCode: CurrencyCode = .gbp,
        createdAt: Date = .now
    ) {
        self.id = id
        self.categoryRaw = category?.rawValue ?? ""
        self.monthlyLimit = monthlyLimit
        self.currencyCodeRaw = currencyCode.rawValue
        self.createdAt = createdAt
    }

    var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) ?? .gbp }
        set { currencyCodeRaw = newValue.rawValue }
    }

    var category: PersonalExpenseCategory? {
        get {
            categoryRaw.isEmpty ? nil : PersonalExpenseCategory(rawValue: categoryRaw)
        }
        set {
            categoryRaw = newValue?.rawValue ?? ""
        }
    }

    var isOverall: Bool { categoryRaw.isEmpty }
}
