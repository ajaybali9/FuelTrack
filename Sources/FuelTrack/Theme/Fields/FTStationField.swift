import SwiftUI

struct FTStationField: View {
    @Binding var station: String
    var pricePence: Double?
    var currencyCode: CurrencyCode = .gbp
    var litersText: String = ""
    var onPickStation: () -> Void
    var onFillFromPrice: (() -> Void)?

    private var liters: Double? {
        Double(litersText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STATION")
                .font(FuelTrackTokens.labelFont())
                .tracking(0.06)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Station name", text: $station)
                    .font(FuelTrackTokens.valueFont())

                Button(action: onPickStation) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(GlassTheme.accent)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(GlassTheme.accent.opacity(0.12))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose station from list")
            }

            if let pricePence {
                HStack(spacing: 8) {
                    Text(String(format: "%.1fp/L", pricePence))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GlassTheme.accentWarm)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            Capsule().fill(GlassTheme.accentWarm.opacity(0.15))
                        }

                    if let liters, liters > 0, currencyCode == .gbp, let onFillFromPrice {
                        Button("Fill total", action: onFillFromPrice)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GlassTheme.accentWarm)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: "Listed at %.1f pence per litre", pricePence))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct FTLiveMetricsStrip: View {
    var pricePerLiter: String?
    var economyHint: String?
    var tint: Color = GlassTheme.accentWarm

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if pricePerLiter != nil || economyHint != nil {
            HStack(spacing: 16) {
                if let pricePerLiter {
                    metric(title: "Price / L", value: pricePerLiter, tint: tint)
                }
                if let economyHint {
                    metric(title: "Economy", value: economyHint, tint: GlassTheme.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)
            }
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    private var accessibilitySummary: String {
        [pricePerLiter.map { "Price per litre \($0)" }, economyHint.map { "Economy \($0)" }]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func metric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.06)
                .foregroundStyle(.secondary)
            Text(value)
                .font(FuelTrackTokens.numericFont(size: .body))
                .foregroundStyle(tint)
        }
    }
}
