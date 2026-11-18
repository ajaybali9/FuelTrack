import SwiftUI

struct FTPlateField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.06)
                .foregroundStyle(.secondary)

            TextField("AB12 CDE", text: $text)
                .font(FuelTrackTokens.plateFont())
                .tracking(1.5)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: FuelTrackTokens.fieldMinHeight)
                .background {
                    RoundedRectangle(cornerRadius: FuelTrackTokens.plateRadius, style: .continuous)
                        .fill(Color.yellow.opacity(0.85))
                        .overlay {
                            RoundedRectangle(cornerRadius: FuelTrackTokens.plateRadius, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
                        }
                }
                .foregroundStyle(.black)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(text.isEmpty ? "Empty" : text)
    }
}

struct FTSecureField: View {
    let label: String
    @Binding var text: String
    var status: String? = nil
    var statusOK: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.06)
                .foregroundStyle(.secondary)

            SecureField(label, text: $text)
                .font(FuelTrackTokens.valueFont())
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(minHeight: FuelTrackTokens.fieldMinHeight)
                .background {
                    RoundedRectangle(cornerRadius: FuelTrackTokens.chipRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                }

            if let status {
                Text(status)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusOK == true ? GlassTheme.success : (statusOK == false ? GlassTheme.error : .secondary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(
                                (statusOK == true ? GlassTheme.success : (statusOK == false ? GlassTheme.error : Color.primary))
                                    .opacity(0.12)
                            )
                    }
                    .accessibilityLabel(status)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}
