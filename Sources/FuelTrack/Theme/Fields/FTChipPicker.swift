import SwiftUI

struct FTChipPicker<T: Hashable & Identifiable>: View where T: CustomStringConvertible {
    let label: String
    @Binding var selection: T
    let options: [T]
    var tint: Color = GlassTheme.accent
    var shortLabel: ((T) -> String)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.06)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        let selected = option.id == selection.id
                        Button {
                            selection = option
                            #if canImport(UIKit)
                            UISelectionFeedbackGenerator().selectionChanged()
                            #endif
                        } label: {
                            Text(shortLabel?(option) ?? option.description)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(selected ? Color.white : .primary)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(selected ? tint : Color.primary.opacity(0.08))
                                }
                                .overlay {
                                    if !selected {
                                        Capsule(style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.description)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

extension CurrencyCode: CustomStringConvertible {
    var description: String { displayName }
}

extension FuelType: CustomStringConvertible {
    var description: String { displayName }
}

extension OdometerUnit: CustomStringConvertible {
    var description: String { displayName }
}

extension AppearancePreference: CustomStringConvertible {
    var description: String { displayName }
}

extension DVLAEnvironment: CustomStringConvertible {
    var description: String { displayName }
}
