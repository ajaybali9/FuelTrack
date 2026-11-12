import SwiftUI

enum GlassTheme {
    static let accent = Color(red: 0.22, green: 0.62, blue: 0.72)
    static let accentWarm = Color(red: 0.92, green: 0.52, blue: 0.22)
    static let deep = Color(red: 0.05, green: 0.10, blue: 0.18)
    static let ink = Color(red: 0.08, green: 0.14, blue: 0.22)
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(GlassTheme.accent.opacity(colorScheme == .dark ? 0.28 : 0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -120, y: -220)

            Circle()
                .fill(GlassTheme.accentWarm.opacity(colorScheme == .dark ? 0.22 : 0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 140, y: 260)
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.45), value: colorScheme)
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.07, green: 0.16, blue: 0.28),
                Color(red: 0.04, green: 0.08, blue: 0.14),
                Color(red: 0.10, green: 0.18, blue: 0.24),
            ]
        }
        return [
            Color(red: 0.93, green: 0.96, blue: 0.99),
            Color(red: 0.88, green: 0.93, blue: 0.97),
            Color(red: 0.95, green: 0.96, blue: 0.98),
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
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
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .scaleEffect(appeared ? 1 : 0.985, anchor: .top)
            .onAppear {
                withAnimation(.smooth(duration: 0.38)) {
                    appeared = true
                }
            }
            .onDisappear {
                appeared = false
            }
    }
}

extension View {
    func fuelTrackScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppBackdrop())
            .toolbarBackground(.hidden, for: .navigationBar)
            .modifier(SmoothPageAppear())
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
