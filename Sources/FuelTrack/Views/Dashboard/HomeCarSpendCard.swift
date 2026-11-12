import SwiftUI

struct HomeCarSpendCard: View {
    let vehicle: Vehicle

    private var stats: VehicleFuelStats {
        FuelStats.compute(vehicle: vehicle)
    }

    private var allTimeFuel: Double { stats.totalSpend }
    private var allTimeCosts: Double { vehicle.costsAllTime }
    private var allTimeTotal: Double { allTimeFuel + allTimeCosts }
    private var yearTotal: Double { stats.spendThisYear + vehicle.costsThisYear }
    private var monthTotal: Double { stats.spendThisMonth + vehicle.costsThisMonth }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Car spend", systemImage: "car.side")
                        .font(.headline)
                    Spacer()
                    Text("From the start")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(Formatters.currency(allTimeTotal, code: vehicle.currencyCode))
                    .font(.title.weight(.bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("Overall · fuel + car costs")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    metric("Fuel", allTimeFuel)
                    metric("Costs", allTimeCosts)
                }

                HStack(spacing: 12) {
                    metric("This year", yearTotal)
                    metric("This month", monthTotal)
                }
            }
        }
    }

    private func metric(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Text(Formatters.currency(value, code: vehicle.currencyCode))
                .font(.subheadline.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}
