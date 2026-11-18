import SwiftUI

/// Shared list/instrument row chrome for the full-app Fuel Computer pass.
struct InstrumentSectionHeader: View {
    let title: String
    var tint: Color = GlassTheme.accent

    var body: some View {
        HStack(spacing: 8) {
            Capsule(style: .continuous)
                .fill(tint)
                .frame(width: 3, height: 14)
            Text(title.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.08)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

struct InstrumentListRow<Content: View>: View {
    var tint: Color = GlassTheme.accent
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(tint)
                            .frame(width: 3)
                            .padding(.vertical, 12)
                            .padding(.leading, 6)
                    }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }
}

struct InstrumentHeroCluster: View {
    let vehicleName: String
    let subtitle: String
    let odometerLine: String?
    let primaryLabel: String
    let primaryValue: String
    let secondaryLabel: String
    let secondaryValue: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ACTIVE VEHICLE")
                            .font(FuelTrackTokens.labelFont())
                            .tracking(0.08)
                            .foregroundStyle(GlassTheme.accent)
                        Text(vehicleName)
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let odometerLine {
                            Text(odometerLine)
                                .font(FuelTrackTokens.numericFont(size: .subheadline))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.title)
                        .foregroundStyle(GlassTheme.accent)
                        .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating, value: appeared)
                }

                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryLabel.uppercased())
                            .font(FuelTrackTokens.labelFont())
                            .tracking(0.06)
                            .foregroundStyle(.secondary)
                        Text(primaryValue)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(GlassTheme.accent)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(secondaryLabel.uppercased())
                            .font(FuelTrackTokens.labelFont())
                            .tracking(0.06)
                            .foregroundStyle(.secondary)
                        Text(secondaryValue)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(GlassTheme.accentWarm)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                }
                .opacity(appeared || reduceMotion ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 12)

                LinearGradient(
                    colors: [GlassTheme.accent, GlassTheme.accentWarm],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 3)
                .clipShape(Capsule())
                .scaleEffect(x: appeared || reduceMotion ? 1 : 0.2, anchor: .leading)
            }
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
                return
            }
            withAnimation(.smooth(duration: 0.55)) {
                appeared = true
            }
        }
    }
}

struct StaggeredAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0.001)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                    return
                }
                withAnimation(.smooth(duration: 0.4).delay(Double(index) * 0.05)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}
