import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore

    @State private var showingPicker = false
    @State private var setFirstVehicleActive = true
    @State private var isImporting = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        GlassFormScaffold {
            GlassFormSection(title: nil, index: 0) {
                Text("Choose a FuelTrack backup JSON from More → Export backup. Vehicles, fill-ups, car spend, personal spend, budgets, reminders, and favourites are restored by ID (safe to import twice).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            GlassFormSection(title: "Options", index: 1) {
                FTToggleRow(
                    label: "Set first restored vehicle as active",
                    isOn: $setFirstVehicleActive
                )
            }

            GlassFormSection(title: nil, index: 2) {
                Button {
                    showingPicker = true
                } label: {
                    if isImporting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Choose backup JSON…", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(GlassTheme.accent)
                .disabled(isImporting)
            }

            if let statusMessage {
                GlassFormSection(title: "Result", index: 3) {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                GlassFormSection(title: "Error", index: 4) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(GlassTheme.error)
                }
            }
        }
        .navigationTitle("Import backup")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importFile(at: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
        }
    }

    private func importFile(at url: URL) {
        isImporting = true
        errorMessage = nil
        statusMessage = nil
        defer { isImporting = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let snapshot = try FuelTrackBackupImporter.parse(data: data)
            let result = try FuelTrackBackupImporter.importSnapshot(snapshot, into: modelContext)

            if setFirstVehicleActive, let first = snapshot.vehicles.first {
                let id = first.id
                if let vehicle = try modelContext.fetch(
                    FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == id })
                ).first {
                    activeVehicleStore.select(vehicle)
                }
            }

            statusMessage = result.summary
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}