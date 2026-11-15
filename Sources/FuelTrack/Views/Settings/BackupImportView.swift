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
        Form {
            Section {
                Text("Choose a FuelTrack backup JSON from More → Export backup. Vehicles, fill-ups, car spend, personal spend, budgets, reminders, and favourites are restored by ID (safe to import twice).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Options") {
                Toggle("Set first restored vehicle as active", isOn: $setFirstVehicleActive)
            }

            Section {
                Button {
                    showingPicker = true
                } label: {
                    if isImporting {
                        ProgressView()
                    } else {
                        Label("Choose backup JSON…", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(isImporting)
            }

            if let statusMessage {
                Section("Result") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
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
