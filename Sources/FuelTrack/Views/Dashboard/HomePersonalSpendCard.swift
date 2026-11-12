import SwiftData
import SwiftUI

struct HomePersonalSpendCard: View {
    @Query(sort: \PersonalExpense.date, order: .reverse) private var expenses: [PersonalExpense]
    @Query private var budgets: [PersonalBudget]
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue

    private var currency: CurrencyCode {
        CurrencyCode(rawValue: defaultCurrencyCode) ?? .gbp
    }

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    }

    private var monthTotal: Double {
        expenses.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.amount }
    }

    private var overallBudget: PersonalBudget? {
        budgets.first(where: \.isOverall)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Personal spend", systemImage: "creditcard.fill")
                        .font(.headline)
                    Spacer()
                    Text("This month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(Formatters.currency(monthTotal, code: currency))
                    .font(.title.weight(.bold))
                if let overallBudget {
                    let limit = overallBudget.monthlyLimit
                    ProgressView(value: min(monthTotal, limit), total: max(limit, 1))
                        .tint(monthTotal > limit ? .orange : GlassTheme.accent)
                    Text(monthTotal > limit
                         ? "Over budget by \(Formatters.currency(monthTotal - limit, code: currency))"
                         : "\(Formatters.currency(limit - monthTotal, code: currency)) left of \(Formatters.currency(limit, code: currency))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Open Spend → Personal to log expenses and set a budget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
