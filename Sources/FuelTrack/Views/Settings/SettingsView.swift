import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue
    @AppStorage("defaultOdometerUnit") private var defaultOdometerUnit = OdometerUnit.miles.rawValue
    @AppStorage("appearancePreference") private var appearancePreference = AppearancePreference.system.rawValue
    @AppStorage("dvlaAPIKey") private var dvlaAPIKey = ""
    @AppStorage("dvlaEnvironment") private var dvlaEnvironmentRaw = DVLAEnvironment.production.rawValue
    @AppStorage("complianceNotificationsEnabled") private var complianceNotificationsEnabled = true

    @State private var isTestingDVLA = false
    @State private var dvlaTestMessage: String?
    @State private var notificationStatusMessage: String?

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
            get: { DVLAEnvironment(rawValue: dvlaEnvironmentRaw) ?? .production },
            set: { dvlaEnvironmentRaw = $0.rawValue }
        )
    }

    private var dvlaEnvironment: DVLAEnvironment {
        DVLAEnvironment(rawValue: dvlaEnvironmentRaw) ?? .production
    }

    private var dvlaTestOK: Bool? {
        guard let dvlaTestMessage else { return nil }
        return dvlaTestMessage.hasPrefix("OK")
    }

    var body: some View {
        GlassFormScaffold {
            GlassFormSection(title: "Appearance", index: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    FTChipPicker(
                        label: "Appearance",
                        selection: appearanceBinding,
                        options: Array(AppearancePreference.allCases)
                    )
                    Text("System follows your iPhone Light/Dark setting.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            GlassFormSection(title: "Defaults for new vehicles", index: 1) {
                VStack(spacing: 14) {
                    FTChipPicker(
                        label: "Currency",
                        selection: currencyBinding,
                        options: Array(CurrencyCode.allCases),
                        tint: GlassTheme.accentWarm,
                        shortLabel: { $0.symbol + " " + $0.rawValue }
                    )
                    FTChipPicker(
                        label: "Odometer unit",
                        selection: unitBinding,
                        options: Array(OdometerUnit.allCases),
                        shortLabel: { $0.shortLabel }
                    )
                }
            }

            GlassFormSection(title: "Reminders", index: 2) {
                VStack(alignment: .leading, spacing: 12) {
                    FTToggleRow(label: "Expiry alerts", isOn: $complianceNotificationsEnabled)
                    Text("Local notifications at 9:00 am: 4 days, 3 days, and 1 day before, plus the morning MOT, road tax, or insurance is due. Opening the app later on the due day still sets a reminder for later that morning.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let notificationStatusMessage {
                        Text(notificationStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: complianceNotificationsEnabled) { _, enabled in
                ComplianceNotificationScheduler.isEnabled = enabled
                Task {
                    if enabled {
                        let ok = await ComplianceNotificationScheduler.requestAuthorizationIfNeeded()
                        notificationStatusMessage = ok
                            ? "Notifications allowed. Alerts will refresh from your vehicle dates."
                            : "Notifications are off in iOS Settings for FuelTrack."
                    } else {
                        await ComplianceNotificationScheduler.cancelAllComplianceNotifications()
                        notificationStatusMessage = "Expiry alerts turned off."
                    }
                }
            }

            GlassFormSection(title: "UK vehicle data", index: 3) {
                VStack(alignment: .leading, spacing: 14) {
                    FTChipPicker(
                        label: "Environment",
                        selection: dvlaEnvironmentBinding,
                        options: Array(DVLAEnvironment.allCases)
                    )

                    FTSecureField(
                        label: "DVLA API key",
                        text: $dvlaAPIKey,
                        status: dvlaTestMessage,
                        statusOK: dvlaTestOK
                    )

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
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(dvlaEnvironment == .test ? "Test connection (AA19MOT)" : "Test connection")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GlassTheme.accent)
                    .disabled(dvlaAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestingDVLA)

                    Link(
                        "DVLA Vehicle Enquiry API portal",
                        destination: URL(string: "https://developer-portal.driver-vehicle-licensing.api.gov.uk/")!
                    )
                    .font(.subheadline)
                }
            }

            GlassFormSection(title: "About", index: 4) {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("App", value: "FuelTrack")
                    LabeledContent("Version", value: "2.2")
                    Text("Fuel + car & personal expenses + stations + MOT/tax (DVLA) + insurance reminders. Glass UI. Data stays on device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: preferProductionDVLA)
    }

    /// Yesterday's build stored Test as the default. Switch once so a real registration is not sent to UAT.
    private func preferProductionDVLA() {
        let reviewedKey = "dvlaEnvironmentReviewed"
        guard !UserDefaults.standard.bool(forKey: reviewedKey) else { return }
        dvlaEnvironmentRaw = DVLAEnvironment.production.rawValue
        UserDefaults.standard.set(true, forKey: reviewedKey)
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