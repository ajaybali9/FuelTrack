import SwiftData
import SwiftUI

struct ReminderListView: View {
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveVehicleStore.self) private var activeVehicleStore
    @State private var showingAdd = false
    @State private var title = ""
    @State private var dueDate = Date.now.addingTimeInterval(30 * 86_400)
    @State private var useDate = true
    @State private var dueOdoText = ""
    @State private var note = ""

    private var activeVehicle: Vehicle? {
        activeVehicleStore.resolve(from: vehicles)
    }

    private var reminders: [ReminderItem] {
        (activeVehicle?.reminders ?? []).sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted && $1.isCompleted }
            return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }
    }

    var body: some View {
        Group {
            if vehicles.isEmpty {
                ContentUnavailableView("Add a vehicle first", systemImage: "car.side")
            } else if reminders.isEmpty {
                ContentUnavailableView(
                    "No reminders",
                    systemImage: "bell",
                    description: Text("Remind yourself about MOT, service or insurance by date or mileage.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(reminders) { item in
                            GlassCard {
                                HStack(alignment: .top, spacing: 12) {
                                    Button {
                                        item.isCompleted.toggle()
                                        try? modelContext.save()
                                    } label: {
                                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundStyle(item.isCompleted ? GlassTheme.accent : .secondary)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                            .strikethrough(item.isCompleted)
                                        if let due = item.dueDate {
                                            Text(due.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let odo = item.dueOdometer, let unit = activeVehicle?.odometerUnit {
                                            Text("At \(Formatters.odometer(odo, unit: unit))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if !item.note.isEmpty {
                                            Text(item.note)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    modelContext.delete(item)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Reminders")
        .fuelTrackScreen()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .disabled(activeVehicle == nil)
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                Form {
                    TextField("Title", text: $title)
                    Toggle("Due date", isOn: $useDate)
                    if useDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                    }
                    TextField("Due odometer (optional)", text: $dueOdoText)
                        .keyboardType(.decimalPad)
                    TextField("Note", text: $note, axis: .vertical)
                }
                .navigationTitle("New reminder")
                .fuelTrackForm()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAdd = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveReminder() }
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func saveReminder() {
        guard let vehicle = activeVehicle else { return }
        let odo = Double(dueOdoText.replacingOccurrences(of: ",", with: "."))
        modelContext.insert(
            ReminderItem(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                dueDate: useDate ? dueDate : nil,
                dueOdometer: odo,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                vehicle: vehicle
            )
        )
        try? modelContext.save()
        Task { await ComplianceNotificationScheduler.reschedule(for: vehicle) }
        title = ""
        note = ""
        dueOdoText = ""
        showingAdd = false
    }
}
