import Foundation
import SwiftData

enum CustomCategoryScope: String, Codable, CaseIterable, Sendable {
    case car
    case personal
}

@Model
final class CustomExpenseCategory {
    var id: UUID
    var name: String
    var systemImage: String
    var scopeRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        systemImage: String = "tag",
        scope: CustomCategoryScope,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.scopeRaw = scope.rawValue
        self.createdAt = createdAt
    }

    var scope: CustomCategoryScope {
        get { CustomCategoryScope(rawValue: scopeRaw) ?? .car }
        set { scopeRaw = newValue.rawValue }
    }

    var storageKey: String {
        SpendCategoryCatalog.customKey(id)
    }
}
