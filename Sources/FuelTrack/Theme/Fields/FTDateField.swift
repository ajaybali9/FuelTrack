import SwiftUI

struct FTDateField: View {
    let label: String
    @Binding var date: Date
    var components: DatePickerComponents = [.date]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.06)
                .foregroundStyle(.secondary)

            DatePicker(
                label,
                selection: $date,
                displayedComponents: components
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

struct FTOptionalDateField: View {
    let label: String
    @Binding var enabled: Bool
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FTToggleRow(label: label, isOn: $enabled)
            if enabled {
                DatePicker(
                    label,
                    selection: $date,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.22), value: enabled)
    }
}

struct FTToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    var caption: String? = nil

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(FuelTrackTokens.valueFont())
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(GlassTheme.accent)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct FTTextArea: View {
    let label: String
    @Binding var text: String
    var lineLimit: ClosedRange<Int> = 2...5

    var body: some View {
        FTTextField(
            label: label,
            text: $text,
            prompt: label,
            axis: .vertical,
            lineLimit: lineLimit
        )
    }
}
