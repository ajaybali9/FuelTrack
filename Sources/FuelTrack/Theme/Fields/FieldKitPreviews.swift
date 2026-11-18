import SwiftUI

#if DEBUG
#Preview("Numeric field states") {
    GlassFormScaffold {
        GlassFormSection(title: "Numbers", index: 0) {
            VStack(spacing: 12) {
                FTNumericField(label: "Odometer", text: .constant("45210"), unit: "mi")
                FTNumericField(label: "Volume", text: .constant(""), unit: "L", isInvalid: true)
                FTNumericField(label: "Total cost", text: .constant("68.40"), unit: "£", tint: GlassTheme.accentWarm)
            }
        }
    }
}

#Preview("Chips & plate") {
    GlassFormScaffold {
        GlassFormSection(title: "Pickers", index: 0) {
            VStack(spacing: 16) {
                FTChipPicker(
                    label: "Currency",
                    selection: .constant(CurrencyCode.gbp),
                    options: CurrencyCode.allCases,
                    tint: GlassTheme.accentWarm,
                    shortLabel: { $0.symbol }
                )
                FTPlateField(label: "Registration", text: .constant("AB12 CDE"))
                FTToggleRow(label: "Full tank", isOn: .constant(true), caption: "Used for full-tank economy")
            }
        }
    }
}

#Preview("Live metrics") {
    VStack {
        Spacer()
        FTLiveMetricsStrip(pricePerLiter: "£1.42", economyHint: "38.2 mpg")
    }
    .background(AppBackdrop())
}
#endif
