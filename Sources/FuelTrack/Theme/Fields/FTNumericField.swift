import SwiftUI

struct FTNumericField: View {
    let label: String
    @Binding var text: String
    var unit: String = ""
    var prompt: String = "0"
    var isInvalid: Bool = false
    var tint: Color = GlassTheme.accent
    var keyboard: FTKeyboard = .decimalPad

    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakeOffset: CGFloat = 0
    @State private var didHapticInvalid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.06)
                .foregroundStyle(isInvalid ? GlassTheme.error : .secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField(prompt, text: $text)
                    .modifier(FTKeyboardModifier(keyboard: keyboard))
                    .font(FuelTrackTokens.numericFont())
                    .multilineTextAlignment(.leading)
                    .focused($focused)
                    .foregroundStyle(isInvalid ? GlassTheme.error : .primary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.9))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: FuelTrackTokens.fieldMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: FuelTrackTokens.chipRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: FuelTrackTokens.chipRadius, style: .continuous)
                            .strokeBorder(
                                isInvalid
                                    ? GlassTheme.error.opacity(0.85)
                                    : (focused ? tint.opacity(0.75) : Color.primary.opacity(0.08)),
                                lineWidth: focused || isInvalid ? 1.5 : 1
                            )
                    }
            }
            .offset(x: shakeOffset)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(text.isEmpty ? "Empty" : "\(text) \(unit)")
        .onChange(of: isInvalid) { _, invalid in
            if invalid {
                triggerInvalidFeedback()
            } else {
                didHapticInvalid = false
            }
        }
    }

    private func triggerInvalidFeedback() {
        guard !didHapticInvalid else { return }
        didHapticInvalid = true
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.35)) {
            shakeOffset = 6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                shakeOffset = 0
            }
        }
    }
}
