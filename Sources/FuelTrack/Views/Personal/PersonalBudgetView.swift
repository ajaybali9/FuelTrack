import SwiftData
import SwiftUI

struct PersonalBudgetView: View {
    @Query private var budgets: [PersonalBudget]
    @Query(sort: \PersonalExpense.date, order: .reverse) private var expenses: [PersonalExpense]
    @Query(sort: \CustomExpenseCategory.createdAt) private var customs: [CustomExpenseCategory]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue

    @State private var overallText = ""
    @State private var categoryLimits: [String: String] = [:]
    @State private var message: String?

    private var currency: CurrencyCode {
        CurrencyCode(rawValue: defaultCurrencyCode) ?? .gbp
    }

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    }

    private var monthExpenses: [PersonalExpense] {
        expenses.filter { $0.date >= monthStart }
    }

    private var categoryOptions: [ResolvedSpendCategory] {
        SpendCategoryCatalog.all(scope: .personal, customs: customs)
    }

    var body: some View {
        Form {
            Section {
                Text("Budgets help you see spend vs plan for personal (non-car) money.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Overall monthly budget") {
                TextField("Limit (\(currency.symbol))", text: $overallText)
                    .keyboardType(.decimalPad)
                let spent = monthExpenses.reduce(0) { $0 + $1.amount }
                Text("Spent this month: \(Formatters.currency(spent, code: currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Category budgets (optional)") {
                ForEach(categoryOptions) { category in
                    HStack {
                        Label(category.name, systemImage: category.systemImage)
                        Spacer()
                        TextField("—", text: binding(for: category.id))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    let spent = monthExpenses.filter { $0.categoryKey == category.id }.reduce(0) { $0 + $1.amount }
                    if spent > 0 {
                        Text("Spent \(Formatters.currency(spent, code: currency))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackForm()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear(perform: load)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { categoryLimits[key] ?? "" },
            set: { categoryLimits[key] = $0 }
        )
    }

    private func load() {
        if let overall = budgets.first(where: \.isOverall) {
            overallText = String(overall.monthlyLimit)
        }
        for budget in budgets where !budget.isOverall {
            categoryLimits[budget.categoryRaw] = String(budget.monthlyLimit)
        }
    }

    private func save() {
        upsertOverall()
        for category in categoryOptions {
            upsertCategory(key: category.id)
        }
        do {
            try modelContext.save()
            message = "Budgets saved."
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }

    private func upsertOverall() {
        let existing = budgets.first(where: \.isOverall)
        let trimmed = overallText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if let existing { modelContext.delete(existing) }
            return
        }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        if let existing {
            existing.monthlyLimit = value
            existing.currencyCode = currency
        } else {
            modelContext.insert(PersonalBudget(category: nil, monthlyLimit: value, currencyCode: currency))
        }
    }

    private func upsertCategory(key: String) {
        let existing = budgets.first { !$0.isOverall && $0.categoryRaw == key }
        let trimmed = (categoryLimits[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if let existing { modelContext.delete(existing) }
            return
        }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        if let existing {
            existing.monthlyLimit = value
            existing.currencyCode = currency
        } else if let builtin = PersonalExpenseCategory(rawValue: key) {
            modelContext.insert(PersonalBudget(category: builtin, monthlyLimit: value, currencyCode: currency))
        } else {
            let budget = PersonalBudget(category: nil, monthlyLimit: value, currencyCode: currency)
            budget.categoryRaw = key
            modelContext.insert(budget)
        }
    }
}
