import SwiftData
import SwiftUI

struct PersonalExpenseListView: View {
    @Query(sort: \PersonalExpense.date, order: .reverse) private var expenses: [PersonalExpense]
    @Query private var budgets: [PersonalBudget]
    @Query(sort: \CustomExpenseCategory.createdAt) private var customs: [CustomExpenseCategory]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue

    @AppStorage("spendPeriod") private var spendPeriodRaw = SpendPeriod.monthly.rawValue
    @State private var showingAdd = false
    @State private var showingBudgets = false
    @State private var filterKey: String?

    /// When embedded in Spend tab, parent owns add/budget toolbars.
    var showsOwnToolbar: Bool = true

    private var currency: CurrencyCode {
        CurrencyCode(rawValue: defaultCurrencyCode) ?? .gbp
    }

    private var period: Binding<SpendPeriod> {
        Binding(
            get: { SpendPeriod(rawValue: spendPeriodRaw) ?? .monthly },
            set: { spendPeriodRaw = $0.rawValue }
        )
    }

    private var selectedPeriod: SpendPeriod {
        SpendPeriod(rawValue: spendPeriodRaw) ?? .monthly
    }

    private var periodStart: Date {
        selectedPeriod.startDate()
    }

    private var monthStart: Date {
        SpendPeriod.monthly.startDate()
    }

    private var periodExpenses: [PersonalExpense] {
        expenses.filter { $0.date >= periodStart }
    }

    private var monthExpenses: [PersonalExpense] {
        expenses.filter { $0.date >= monthStart }
    }

    private var filteredExpenses: [PersonalExpense] {
        let base = periodExpenses
        guard let filterKey else { return base }
        return base.filter { $0.categoryKey == filterKey }
    }

    private var yearStart: Date {
        SpendPeriod.yearly.startDate()
    }

    private var periodTotal: Double {
        periodExpenses.reduce(0) { $0 + $1.amount }
    }

    private var monthTotal: Double {
        monthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var yearTotal: Double {
        expenses.filter { $0.date >= yearStart }.reduce(0) { $0 + $1.amount }
    }

    private var allTimeTotal: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private var overallBudget: PersonalBudget? {
        budgets.first(where: \.isOverall)
    }

    private var categoryRows: [CategorySpendRow] {
        let keys = Set(expenses.map(\.categoryKey))
        return keys.compactMap { key -> CategorySpendRow? in
            let items = expenses.filter { $0.categoryKey == key }
            let periodItems = items.filter { $0.date >= periodStart }
            let periodSum = periodItems.reduce(0) { $0 + $1.amount }
            guard periodSum > 0 else { return nil }
            let all = items.reduce(0) { $0 + $1.amount }
            let category = SpendCategoryCatalog.resolve(key: key, scope: .personal, customs: customs)
            return CategorySpendRow(
                id: key,
                category: category,
                periodTotal: periodSum,
                allTimeTotal: all,
                entryCount: periodItems.count
            )
        }
        .sorted { $0.periodTotal > $1.periodTotal }
    }

    var body: some View {
        Group {
            if expenses.isEmpty {
                ContentUnavailableView(
                    "No personal expenses",
                    systemImage: "creditcard",
                    description: Text("Track food, bills, shopping and more — separate from car costs.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        SpendTotalsCard(
                            periodTotal: periodTotal,
                            allTimeTotal: allTimeTotal,
                            yearTotal: yearTotal,
                            currency: currency,
                            periodEntryCount: periodExpenses.count,
                            subtitle: "Personal",
                            period: period
                        )

                        if let overallBudget, selectedPeriod == .monthly {
                            GlassCard {
                                let limit = overallBudget.monthlyLimit
                                let remaining = limit - monthTotal
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Monthly budget")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ProgressView(value: min(monthTotal, limit), total: max(limit, 1))
                                        .tint(remaining < 0 ? .orange : GlassTheme.accent)
                                    Text(
                                        remaining >= 0
                                            ? "\(Formatters.currency(remaining, code: currency)) left of \(Formatters.currency(limit, code: overallBudget.currencyCode))"
                                            : "Over by \(Formatters.currency(-remaining, code: currency))"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(remaining < 0 ? Color.orange : .secondary)
                                }
                            }
                        }

                        CategorySpendBreakdownCard(
                            rows: categoryRows,
                            currency: currency,
                            period: selectedPeriod,
                            selectedKey: filterKey,
                            onSelect: { filterKey = $0 }
                        )

                        LazyVStack(spacing: 12) {
                            ForEach(filteredExpenses) { expense in
                                NavigationLink {
                                    PersonalExpenseFormView(expense: expense)
                                } label: {
                                    expenseRow(expense)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        modelContext.delete(expense)
                                        try? modelContext.save()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .modifier(PersonalToolbarModifier(
            enabled: showsOwnToolbar,
            showingAdd: $showingAdd,
            showingBudgets: $showingBudgets
        ))
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                PersonalExpenseFormView(expense: nil)
            }
        }
        .sheet(isPresented: $showingBudgets) {
            NavigationStack {
                PersonalBudgetView()
            }
        }
    }

    private func expenseRow(_ expense: PersonalExpense) -> some View {
        let resolved = SpendCategoryCatalog.resolve(key: expense.categoryKey, scope: .personal, customs: customs)
        return GlassCard {
            HStack(spacing: 12) {
                Image(systemName: resolved.systemImage)
                    .foregroundStyle(GlassTheme.accent)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: .circle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(resolved.name) · \(Formatters.shortDate(expense.date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !expense.note.isEmpty {
                        Text(expense.note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(Formatters.currency(expense.amount, code: expense.currencyCode))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
    }
}

private struct PersonalToolbarModifier: ViewModifier {
    let enabled: Bool
    @Binding var showingAdd: Bool
    @Binding var showingBudgets: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .navigationTitle("Personal")
                .fuelTrackScreen()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingBudgets = true } label: {
                            Image(systemName: "chart.pie")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingAdd = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
        } else {
            content
        }
    }
}
