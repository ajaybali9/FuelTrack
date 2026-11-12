import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue
    @AppStorage("defaultOdometerUnit") private var defaultOdometerUnit = OdometerUnit.miles.rawValue

    private var currencyBinding: Binding<CurrencyCode> {
        Binding(
            get: { CurrencyCode(rawValue: defaultCurrencyCode) ?? .gbp },
            set: { defaultCurrencyCode = $0.rawValue }
        )
    }

    private var unitBinding: Binding<OdometerUnit> {
        Binding(
            get: { OdometerUnit(rawValue: defaultOdometerUnit) ?? .miles },
            set: { defaultOdometerUnit = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Defaults for new vehicles") {
                    Picker("Currency", selection: currencyBinding) {
                        ForEach(CurrencyCode.allCases) { code in
                            Text(code.displayName).tag(code)
                        }
                    }
                    Picker("Odometer unit", selection: unitBinding) {
                        ForEach(OdometerUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "FuelTrack")
                    LabeledContent("Version", value: "1.0")
                    Text("Fuel-only tracker with multi-vehicle support, GBP/INR, and full-tank consumption stats. Data stays on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
