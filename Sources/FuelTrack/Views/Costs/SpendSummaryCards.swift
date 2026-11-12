import SwiftUI

enum SpendPeriod: String, CaseIterable, Identifiable {
    case monthly
    case yearly
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Month"
        case .yearly: "Year"
        case .allTime: "All"
        }
    }

    var periodLabel: String {
        switch self {
        case .monthly: "This month"
        case .yearly: "This year"
        case .allTime: "All time"
        }
    }

    var shortLabel: String {
        switch self {
        case .monthly: "Month"
        case .yearly: "Year"
        case .allTime: "All time"
        }
    }

    var entryScopePhrase: String {
        switch self {
        case .monthly: "this month"
        case .yearly: "this year"
        case .allTime: "all time"
        }
    }

    var emptyPeriodPhrase: String {
        switch self {
        case .monthly: "month"
        case .yearly: "year"
        case .allTime: "history"
        }
    }

    func startDate(calendar: Calendar = .current, now: Date = .now) -> Date {
        switch self {
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .yearly:
            return calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        case .allTime:
            return .distantPast
        }
    }
}

struct SpendTotalsCard: View {
    let periodTotal: Double
    let allTimeTotal: Double
    let yearTotal: Double
    let currency: CurrencyCode
    var periodEntryCount: Int
    var subtitle: String = ""
    @Binding var period: SpendPeriod

    private var secondaryLabel: String {
        period == .allTime ? "This year" : "All time"
    }

    private var secondaryValue: Double {
        period == .allTime ? yearTotal : allTimeTotal
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Picker("Period", selection: $period) {
                        ForEach(SpendPeriod.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(period.periodLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Formatters.currency(periodTotal, code: currency))
                            .font(.title.weight(.bold))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(secondaryLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Formatters.currency(secondaryValue, code: currency))
                            .font(.title3.weight(.semibold))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                }

                Text("\(periodEntryCount) entr\(periodEntryCount == 1 ? "y" : "ies") · \(period.entryScopePhrase)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.smooth(duration: 0.28), value: period)
    }
}

struct CategorySpendBreakdownCard: View {
    let rows: [CategorySpendRow]
    let currency: CurrencyCode
    var period: SpendPeriod
    var selectedKey: String?
    var onSelect: (String?) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("By category · \(period.shortLabel.lowercased())")
                        .font(.headline)
                    Spacer()
                    if selectedKey != nil {
                        Button("Clear") { onSelect(nil) }
                            .font(.caption.weight(.semibold))
                    }
                }

                if rows.isEmpty {
                    Text("No spend in this \(period.emptyPeriodPhrase) yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows) { row in
                        Button {
                            onSelect(selectedKey == row.id ? nil : row.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: row.category.systemImage)
                                    .foregroundStyle(GlassTheme.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.category.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if period != .allTime {
                                        Text("\(row.entryCount) · all-time \(Formatters.currency(row.allTimeTotal, code: currency))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("\(row.entryCount) entries")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(Formatters.currency(row.periodTotal, code: currency))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .contentTransition(.numericText())
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selectedKey == row.id ? GlassTheme.accent.opacity(0.16) : .clear)
                            )
                        }
                        .buttonStyle(.plain)

                        if row.periodTotal > 0 {
                            let maxTotal = max(rows.map(\.periodTotal).max() ?? 1, 1)
                            ProgressView(value: row.periodTotal, total: maxTotal)
                                .tint(selectedKey == row.id ? GlassTheme.accentWarm : GlassTheme.accent)
                        }
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.28), value: period)
    }
}
