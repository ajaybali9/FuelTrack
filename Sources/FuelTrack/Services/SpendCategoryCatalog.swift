import Foundation

struct ResolvedSpendCategory: Identifiable, Hashable, Sendable, CustomStringConvertible {
    var id: String
    var name: String
    var systemImage: String
    var isCustom: Bool

    var description: String { name }
}

enum SpendCategoryCatalog {
    static func customKey(_ id: UUID) -> String {
        "c:\(id.uuidString)"
    }

    static func isCustomKey(_ key: String) -> Bool {
        key.hasPrefix("c:")
    }

    static func builtins(for scope: CustomCategoryScope) -> [ResolvedSpendCategory] {
        switch scope {
        case .car:
            return CostCategory.allCases.map {
                ResolvedSpendCategory(
                    id: $0.rawValue,
                    name: $0.displayName,
                    systemImage: $0.systemImage,
                    isCustom: false
                )
            }
        case .personal:
            return PersonalExpenseCategory.allCases.map {
                ResolvedSpendCategory(
                    id: $0.rawValue,
                    name: $0.displayName,
                    systemImage: $0.systemImage,
                    isCustom: false
                )
            }
        }
    }

    static func all(
        scope: CustomCategoryScope,
        customs: [CustomExpenseCategory]
    ) -> [ResolvedSpendCategory] {
        let customItems = customs
            .filter { $0.scope == scope }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map {
                ResolvedSpendCategory(
                    id: $0.storageKey,
                    name: $0.name,
                    systemImage: $0.systemImage.isEmpty ? "tag" : $0.systemImage,
                    isCustom: true
                )
            }
        return builtins(for: scope) + customItems
    }

    static func resolve(
        key: String,
        scope: CustomCategoryScope,
        customs: [CustomExpenseCategory]
    ) -> ResolvedSpendCategory {
        if let match = all(scope: scope, customs: customs).first(where: { $0.id == key }) {
            return match
        }
        if let builtin = builtins(for: scope).first(where: { $0.id == key }) {
            return builtin
        }
        return ResolvedSpendCategory(
            id: key,
            name: key.isEmpty ? "Other" : key,
            systemImage: "ellipsis.circle",
            isCustom: isCustomKey(key)
        )
    }
}

struct CategorySpendRow: Identifiable {
    var id: String
    var category: ResolvedSpendCategory
    var periodTotal: Double
    var allTimeTotal: Double
    var entryCount: Int
}
