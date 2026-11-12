import SwiftData
import SwiftUI

struct MoreView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @State private var exportURL: URL?
    @State private var showingExporter = false
    @State private var exportError: String?

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    NavigationLink {
                        VehicleListView()
                    } label: {
                        moreRow("Vehicles", subtitle: "\(vehicles.count) cars", icon: "car.side")
                    }
                    NavigationLink {
                        ReminderListView()
                    } label: {
                        moreRow("Reminders", subtitle: "MOT, service, insurance", icon: "bell")
                    }
                    NavigationLink {
                        PersonalExpenseListView()
                    } label: {
                        moreRow("Personal expenses", subtitle: "Food, bills, budgets", icon: "creditcard")
                    }
                    NavigationLink {
                        FuelioImportView()
                    } label: {
                        moreRow("Import Fuelio CSV", subtitle: "Bring your history across", icon: "square.and.arrow.down")
                    }
                    Button {
                        exportActiveVehicle()
                    } label: {
                        moreRow("Export CSV", subtitle: activeVehicle?.name ?? "Select a vehicle", icon: "square.and.arrow.up")
                    }
                    .disabled(activeVehicle == nil)
                    NavigationLink {
                        SettingsView()
                    } label: {
                        moreRow("Settings", subtitle: "Currency, units, about", icon: "gearshape")
                    }

                    if let exportError {
                        Text(exportError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("More")
            .fuelTrackScreen()
            .sheet(isPresented: $showingExporter) {
                if let exportURL {
                    ShareSheet(url: exportURL)
                }
            }
        }
    }

    private func moreRow(_ title: String, subtitle: String, icon: String) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(GlassTheme.accent)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func exportActiveVehicle() {
        guard let vehicle = activeVehicle else { return }
        do {
            let csv = FuelioCSVExporter.export(vehicle: vehicle)
            let safeName = vehicle.name.replacingOccurrences(of: "/", with: "-")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("FuelTrack-\(safeName).csv")
            try csv.data(using: .utf8)?.write(to: url)
            exportURL = url
            showingExporter = true
            exportError = nil
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
