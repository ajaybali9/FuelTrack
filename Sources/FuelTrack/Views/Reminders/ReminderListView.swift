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
                    LazyVStack(spacing: 10) {
                        ForEach(Array(reminders.enumerated()), id: \.element.id) { index, item in
                            reminderRow(item)
                                .staggeredAppear(index: index)
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
                GlassFormScaffold {
                    GlassFormSection(title: nil, index: 0) {
                        VStack(spacing: 14) {
                            FTTextField(label: "Title", text: $title, prompt: "Title")
                            FTOptionalDateField(
                                label: "Due date",
                                enabled: $useDate,
                                date: $dueDate
                            )
                            FTNumericField(
                                label: "Due odometer",
                                text: $dueOdoText,
                                unit: activeVehicle?.odometerUnit.shortLabel ?? "",
                                prompt: "Optional"
                            )
                            FTTextArea(label: "Note", text: $note, lineLimit: 2...4)
                        }
                    }
                }
                .navigationTitle("New reminder")
                .navigationBarTitleDisplayMode(.inline)
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

    private func reminderRowTint(_ item: ReminderItem) -> Color {
        guard !item.isCompleted, isDueSoon(item) else { return GlassTheme.accent }
        return GlassTheme.accentWarm
    }

    private func isDueSoon(_ item: ReminderItem) -> Bool {
        guard let due = item.dueDate else { return false }
        let calendar = Calendar.current
        let dueDay = calendar.startOfDay(for: due)
        let today = calendar.startOfDay(for: .now)
        let days = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 999
        return days <= ReminderSchedule.leadDays.max() ?? 4
    }

    @ViewBuilder
    private func reminderRow(_ item: ReminderItem) -> some View {
        let tint = reminderRowTint(item)
        InstrumentListRow(tint: tint) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    item.isCompleted.toggle()
                    try? modelContext.save()
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isCompleted ? GlassTheme.accent : tint)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    if let due = item.dueDate {
                        Text(due.formatted(date: .abbreviated, time: .omitted))
                            .font(FuelTrackTokens.numericFont(size: .caption))
                            .foregroundStyle(isDueSoon(item) && !item.isCompleted ? tint : .secondary)
                    }
                    if let odo = item.dueOdometer, let unit = activeVehicle?.odometerUnit {
                        Text("At \(Formatters.odometer(odo, unit: unit))")
                            .font(FuelTrackTokens.numericFont(size: .caption))
                            .foregroundStyle(.secondary)
                    }
                    if !item.note.isEmpty {
                        Text(item.note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
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
