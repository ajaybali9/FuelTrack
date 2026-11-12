import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue
    @AppStorage("defaultOdometerUnit") private var defaultOdometerUnit = OdometerUnit.miles.rawValue
    @AppStorage("appearancePreference") private var appearancePreference = AppearancePreference.system.rawValue
    @AppStorage("dvlaAPIKey") private var dvlaAPIKey = ""

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

    private var appearanceBinding: Binding<AppearancePreference> {
        Binding(
            get: { AppearancePreference(rawValue: appearancePreference) ?? .system },
            set: { appearancePreference = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                Text("System follows your iPhone Light/Dark setting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Appearance")
            }

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

            Section {
                SecureField("DVLA API key", text: $dvlaAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Used for MOT & road-tax status via the official DVLA Vehicle Enquiry API. Insurance is not published by DVLA — enter renewal dates on each vehicle.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Link(
                    "Register for DVLA Vehicle Enquiry API",
                    destination: URL(string: "https://developer-portal.driver-vehicle-licensing.api.gov.uk/")!
                )
                Link(
                    "Optional: DVSA MOT History API",
                    destination: URL(string: "https://documentation.history.mot.api.gov.uk/mot-history-api/register")!
                )
            } header: {
                Text("UK vehicle data")
            }

            Section("About") {
                LabeledContent("App", value: "FuelTrack")
                LabeledContent("Version", value: "2.1")
                Text("Fuel + car & personal expenses + stations + MOT/tax (DVLA) + insurance reminders. Glass UI. Data stays on device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
    }
}
