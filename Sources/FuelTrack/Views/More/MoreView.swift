import SwiftData
import SwiftUI

struct MoreView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(sort: \PersonalExpense.date, order: .reverse) private var personalExpenses: [PersonalExpense]
    @Query(sort: \PersonalBudget.createdAt) private var personalBudgets: [PersonalBudget]
    @Query(sort: \CustomExpenseCategory.name) private var customCategories: [CustomExpenseCategory]
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore

    @State private var shareItem: ShareableFile?
    @State private var exportError: String?

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    private var backupSubtitle: String {
        let fillCount = vehicles.reduce(0) { $0 + $1.fillUps.count }
        let carSpend = vehicles.reduce(0) { $0 + $1.costs.count }
        return "\(vehicles.count) cars · \(fillCount) fill-ups · \(carSpend + personalExpenses.count) spend"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    InstrumentSectionHeader(title: "Garage", tint: GlassTheme.accent)
                        .staggeredAppear(index: 0)

                    NavigationLink {
                        VehicleListView()
                    } label: {
                        moreRow("Vehicles", subtitle: "\(vehicles.count) cars", icon: "car.side", tint: GlassTheme.accent)
                    }
                    .staggeredAppear(index: 1)

                    NavigationLink {
                        ReminderListView()
                    } label: {
                        moreRow("Reminders", subtitle: "MOT, service, insurance", icon: "bell", tint: GlassTheme.accent)
                    }
                    .staggeredAppear(index: 2)

                    NavigationLink {
                        if let activeVehicle {
                            TripListView(vehicle: activeVehicle)
                        } else {
                            ContentUnavailableView(
                                "Select a vehicle",
                                systemImage: "car.side",
                                description: Text("Pick an active vehicle to see trip history.")
                            )
                        }
                    } label: {
                        moreRow(
                            "Trip Logger",
                            subtitle: "GPS trips & routes",
                            icon: "point.topleft.down.to.point.bottomright.curvepath",
                            tint: GlassTheme.accent
                        )
                    }
                    .staggeredAppear(index: 3)

                    NavigationLink {
                        NearbyGaragesView()
                    } label: {
                        moreRow(
                            "Nearby garages",
                            subtitle: "MOT centres & repair",
                            icon: "wrench.and.screwdriver",
                            tint: GlassTheme.accent
                        )
                    }
                    .staggeredAppear(index: 4)

                    InstrumentSectionHeader(title: "Money", tint: GlassTheme.accentWarm)
                        .staggeredAppear(index: 5)

                    NavigationLink {
                        PersonalExpenseListView()
                    } label: {
                        moreRow(
                            "Personal expenses",
                            subtitle: "Food, bills, budgets",
                            icon: "creditcard",
                            tint: GlassTheme.accentWarm
                        )
                    }
                    .staggeredAppear(index: 6)

                    InstrumentSectionHeader(title: "System")
                        .staggeredAppear(index: 7)

                    NavigationLink {
                        BackupImportView()
                    } label: {
                        moreRow(
                            "Import backup",
                            subtitle: "Restore full FuelTrack JSON",
                            icon: "externaldrive.badge.checkmark"
                        )
                    }
                    .staggeredAppear(index: 8)

                    Button {
                        exportFullBackup()
                    } label: {
                        moreRow(
                            "Export backup",
                            subtitle: backupSubtitle,
                            icon: "externaldrive.badge.timemachine"
                        )
                    }
                    .accessibilityHint("Creates a shareable FuelTrack JSON backup")
                    .staggeredAppear(index: 9)

                    NavigationLink {
                        SettingsView()
                    } label: {
                        moreRow("Settings", subtitle: "Currency, units, about", icon: "gearshape")
                    }
                    .staggeredAppear(index: 10)

                    if let exportError {
                        Text(exportError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("More")
            .fuelTrackScreen()
            .sheet(item: $shareItem) { item in
                ShareSheet(url: item.url)
            }
        }
    }

    private func moreRow(
        _ title: String,
        subtitle: String,
        icon: String,
        tint: Color = GlassTheme.accent
    ) -> some View {
        InstrumentListRow(tint: tint) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func exportFullBackup() {
        do {
            let url = try FuelTrackBackupExporter.writeBackupFile(
                vehicles: vehicles,
                personalExpenses: personalExpenses,
                personalBudgets: personalBudgets,
                customCategories: customCategories
            )
            shareItem = ShareableFile(url: url)
            exportError = nil
        } catch {
            exportError = error.localizedDescription
        }
    }

}

private struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
        ]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}