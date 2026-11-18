import SwiftUI

enum GlassTheme {
    static let accent = FuelTrackTokens.accent
    static let accentWarm = FuelTrackTokens.accentWarm
    static let deep = FuelTrackTokens.deep
    static let ink = FuelTrackTokens.ink
    static let success = FuelTrackTokens.success
    static let warning = FuelTrackTokens.warning
    static let error = FuelTrackTokens.error
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct AppBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(GlassTheme.accent.opacity(colorScheme == .dark ? 0.38 : 0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 55)
                .offset(x: -130, y: -240)

            Circle()
                .fill(GlassTheme.accentWarm.opacity(colorScheme == .dark ? 0.30 : 0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 65)
                .offset(x: 150, y: 280)

            Circle()
                .fill(GlassTheme.accent.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .frame(width: 180, height: 180)
                .blur(radius: 40)
                .offset(x: 80, y: -40)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: colorScheme)
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.12, blue: 0.22),
                Color(red: 0.03, green: 0.06, blue: 0.11),
                Color(red: 0.12, green: 0.14, blue: 0.18),
            ]
        }
        return [
            Color(red: 0.90, green: 0.95, blue: 0.98),
            Color(red: 0.94, green: 0.93, blue: 0.90),
            Color(red: 0.88, green: 0.92, blue: 0.96),
        ]
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }
}

struct GlassStatChip: View {
    let title: String
    let value: String
    var tint: Color = GlassTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(FuelTrackTokens.numericFont(size: .title3))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText())
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint.opacity(0.85))
                .frame(width: 28, height: 3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }
}

struct SmoothPageAppear: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : (reduceMotion ? 1 : 0.001))
            .offset(y: appeared || reduceMotion ? 0 : 8)
            .onAppear {
                // Do not reset on disappear — NavigationStack keeps parents around when
                // pushing Settings/etc, and zeroing opacity caused a black screen on back.
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                    return
                }
                withAnimation(.smooth(duration: 0.32)) {
                    appeared = true
                }
            }
    }
}

extension View {
    /// Scroll screens with the shared backdrop + entrance.
    func fuelTrackScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppBackdrop())
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(SmoothPageAppear())
    }

    /// Forms / sheets: same backdrop as screens, without entrance animation.
    func fuelTrackForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppBackdrop())
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    func smoothContentTransition() -> some View {
        self.transition(
            .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .offset(y: 6)),
                removal: .opacity.combined(with: .move(edge: .leading))
            )
        )
    }
}
