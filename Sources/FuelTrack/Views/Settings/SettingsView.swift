import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue
    @AppStorage("defaultOdometerUnit") private var defaultOdometerUnit = OdometerUnit.miles.rawValue
    @AppStorage("appearancePreference") private var appearancePreference = AppearancePreference.system.rawValue
    @AppStorage("dvlaAPIKey") private var dvlaAPIKey = ""
    @AppStorage("dvlaEnvironment") private var dvlaEnvironmentRaw = DVLAEnvironment.test.rawValue

    @State private var isTestingDVLA = false
    @State private var dvlaTestMessage: String?

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

    private var dvlaEnvironmentBinding: Binding<DVLAEnvironment> {
        Binding(
            get: { DVLAEnvironment(rawValue: dvlaEnvironmentRaw) ?? .test },
            set: { dvlaEnvironmentRaw = $0.rawValue }
        )
    }

    private var dvlaEnvironment: DVLAEnvironment {
        DVLAEnvironment(rawValue: dvlaEnvironmentRaw) ?? .test
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
                Picker("Environment", selection: dvlaEnvironmentBinding) {
                    ForEach(DVLAEnvironment.allCases) { env in
                        Text(env.displayName).tag(env)
                    }
                }
                .pickerStyle(.segmented)

                SecureField("DVLA API key", text: $dvlaAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if dvlaEnvironment == .test {
                    Text("Test mode uses DVLA UAT with mock plates only (e.g. AA19MOT, AA19AAA). Real registrations will not work until you switch to Production with a live key.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Production looks up real UK registrations for MOT & road tax. Insurance is not published by DVLA.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await testDVLAConnection() }
                } label: {
                    if isTestingDVLA {
                        ProgressView()
                    } else {
                        Text(dvlaEnvironment == .test ? "Test connection (AA19MOT)" : "Test connection")
                    }
                }
                .disabled(dvlaAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestingDVLA)

                if let dvlaTestMessage {
                    Text(dvlaTestMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Link(
                    "DVLA Vehicle Enquiry API portal",
                    destination: URL(string: "https://developer-portal.driver-vehicle-licensing.api.gov.uk/")!
                )
            } header: {
                Text("UK vehicle data")
            }

            Section("About") {
                LabeledContent("App", value: "FuelTrack")
                LabeledContent("Version", value: "2.2")
                Text("Fuel + car & personal expenses + stations + MOT/tax (DVLA) + insurance reminders. Glass UI. Data stays on device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    @MainActor
    private func testDVLAConnection() async {
        isTestingDVLA = true
        dvlaTestMessage = nil
        defer { isTestingDVLA = false }

        let plate = dvlaEnvironment == .test ? DVLAEnvironment.testSuccessRegistration : "AA19AAA"
        do {
            let details = try await DVLAVehicleService.fetch(
                registration: plate,
                apiKey: dvlaAPIKey,
                environment: dvlaEnvironment
            )
            let mot = details.motStatus ?? "—"
            let tax = details.taxStatus ?? "—"
            let make = details.make ?? "—"
            dvlaTestMessage = "OK · \(details.registrationNumber) · \(make) · MOT \(mot) · Tax \(tax)"
        } catch {
            dvlaTestMessage = error.localizedDescription
        }
    }
}
