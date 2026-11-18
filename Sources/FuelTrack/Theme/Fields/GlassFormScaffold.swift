import SwiftUI

struct GlassFormSection<Content: View>: View {
    let title: String?
    var index: Int = 0
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title, !title.isEmpty {
                Text(title.uppercased())
                    .font(FuelTrackTokens.labelFont())
                    .tracking(0.06)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
            }

            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: FuelTrackTokens.cardRadius))
        }
        .opacity(appeared || reduceMotion ? 1 : 0.001)
        .offset(y: appeared || reduceMotion ? 0 : 10)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
                return
            }
            let delay = Double(index) * 0.04
            withAnimation(.smooth(duration: 0.32).delay(delay)) {
                appeared = true
            }
        }
    }
}

struct GlassFormScaffold<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FuelTrackTokens.sectionSpacing) {
                content
            }
            .padding(.horizontal, FuelTrackTokens.horizontalPadding)
            .padding(.vertical, 12)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .fuelTrackForm()
    }
}

struct FTTextField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var disableAutocorrection: Bool = false
    var keyboard: FTKeyboard = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.06)
                .foregroundStyle(.secondary)
            Group {
                if let lineLimit {
                    TextField(prompt.isEmpty ? label : prompt, text: $text, axis: .vertical)
                        .lineLimit(lineLimit)
                } else {
                    TextField(prompt.isEmpty ? label : prompt, text: $text)
                }
            }
            .font(FuelTrackTokens.valueFont())
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(disableAutocorrection)
            .modifier(FTKeyboardModifier(keyboard: keyboard))
            .frame(minHeight: axis == .horizontal ? 28 : nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(text.isEmpty ? "Empty" : text)
    }
}
