import Foundation
import UserNotifications

enum ComplianceNotificationScheduler {
    private static let enabledKey = "complianceNotificationsEnabled"
    /// 4 days, 3 days, 1 day, and the morning of the due date.
    static let leadDays = ReminderSchedule.leadDays

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    @MainActor
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    @MainActor
    static func reschedule(for vehicles: [Vehicle]) async {
        let center = UNUserNotificationCenter.current()
        await cancelAllComplianceNotifications()

        guard isEnabled else { return }
        let allowed = await requestAuthorizationIfNeeded()
        guard allowed else { return }

        for vehicle in vehicles {
            await schedule(for: vehicle, center: center)
            await scheduleReminders(for: vehicle, center: center)
        }
    }

    @MainActor
    static func reschedule(for vehicle: Vehicle) async {
        await cancel(for: vehicle)
        guard isEnabled else { return }
        let allowed = await requestAuthorizationIfNeeded()
        guard allowed else { return }
        await schedule(for: vehicle, center: .current())
        await scheduleReminders(for: vehicle, center: .current())
    }

    @MainActor
    private static func schedule(for vehicle: Vehicle, center: UNUserNotificationCenter) async {
        let plate = vehicle.displayPlate.isEmpty ? vehicle.name : vehicle.displayPlate
        let items: [(kind: String, title: String, date: Date?)] = [
            ("mot", "MOT", vehicle.motExpiry),
            ("tax", "Road tax", vehicle.taxDueDate),
            ("insurance", "Insurance", vehicle.insuranceExpiry),
        ]

        for item in items {
            guard let due = item.date else { continue }
            for days in leadDays {
                guard let contentDate = ReminderSchedule.notificationDate(daysBefore: days, dueDate: due) else { continue }
                await add(
                    center: center,
                    id: notificationID(vehicleID: vehicle.id, kind: item.kind, daysBefore: days),
                    title: "\(item.title) due soon",
                    body: body(plate: plate, title: item.title, daysBefore: days, due: due),
                    fire: contentDate,
                    userInfo: [
                        "vehicleId": vehicle.id.uuidString,
                        "kind": item.kind,
                        "daysBefore": days,
                    ]
                )
            }
            if let catchUp = ReminderSchedule.catchUpDate(dueDate: due) {
                await add(
                    center: center,
                    id: notificationID(vehicleID: vehicle.id, kind: item.kind, daysBefore: -1),
                    title: "\(item.title) due today",
                    body: "\(plate) · \(item.title) expires today (\(Formatters.shortDate(due))).",
                    fire: catchUp,
                    userInfo: [
                        "vehicleId": vehicle.id.uuidString,
                        "kind": item.kind,
                        "daysBefore": 0,
                    ]
                )
            }
        }
    }

    @MainActor
    private static func scheduleReminders(for vehicle: Vehicle, center: UNUserNotificationCenter) async {
        let open = vehicle.reminders.filter { !$0.isCompleted }
        let samples = vehicle.sortedFillUps.suffix(2)
        for item in open {
            if let due = item.dueDate {
                for days in leadDays {
                    guard let fire = ReminderSchedule.notificationDate(daysBefore: days, dueDate: due) else { continue }
                    await add(
                        center: center,
                        id: reminderID(vehicleID: vehicle.id, reminderID: item.id, suffix: "d\(days)"),
                        title: item.title,
                        body: body(plate: vehicle.name, title: item.title, daysBefore: days, due: due),
                        fire: fire,
                        userInfo: ["vehicleId": vehicle.id.uuidString, "reminderId": item.id.uuidString]
                    )
                }
                if let catchUp = ReminderSchedule.catchUpDate(dueDate: due) {
                    await add(
                        center: center,
                        id: reminderID(vehicleID: vehicle.id, reminderID: item.id, suffix: "catchup"),
                        title: item.title,
                        body: "\(item.title) is due today.",
                        fire: catchUp,
                        userInfo: ["vehicleId": vehicle.id.uuidString, "reminderId": item.id.uuidString]
                    )
                }
            } else if let dueOdo = item.dueOdometer,
                      samples.count == 2,
                      let earlier = samples.first,
                      let latest = samples.last,
                      let fire = ReminderSchedule.odometerFireDate(
                        dueOdometer: dueOdo,
                        latestOdometer: latest.odometer,
                        latestDate: latest.date,
                        earlierOdometer: earlier.odometer,
                        earlierDate: earlier.date
                      ) {
                let unit = vehicle.odometerUnit.shortLabel
                await add(
                    center: center,
                    id: reminderID(vehicleID: vehicle.id, reminderID: item.id, suffix: "odo"),
                    title: item.title,
                    body: "\(vehicle.name) · \(item.title) is coming up around \(Int(dueOdo)) \(unit).",
                    fire: fire,
                    userInfo: ["vehicleId": vehicle.id.uuidString, "reminderId": item.id.uuidString]
                )
            }
        }
    }

    private static func body(plate: String, title: String, daysBefore: Int, due: Date) -> String {
        let when = daysBefore == 0 ? "today" : "in \(ReminderSchedule.leadLabel(daysBefore: daysBefore))"
        return "\(plate) · \(title) expires \(when) (\(Formatters.shortDate(due)))."
    }

    @MainActor
    private static func add(
        center: UNUserNotificationCenter,
        id: String,
        title: String,
        body: String,
        fire: Date,
        userInfo: [AnyHashable: Any]
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func notificationID(vehicleID: UUID, kind: String, daysBefore: Int) -> String {
        "fueltrack.compliance.\(vehicleID.uuidString).\(kind).d\(daysBefore)"
    }

    private static func reminderID(vehicleID: UUID, reminderID: UUID, suffix: String) -> String {
        "fueltrack.reminder.\(vehicleID.uuidString).\(reminderID.uuidString).\(suffix)"
    }

    @MainActor
    static func cancel(for vehicle: Vehicle) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let token = vehicle.id.uuidString
        let ids = pending.map(\.identifier).filter {
            $0.contains(token) && ($0.hasPrefix("fueltrack.compliance.") || $0.hasPrefix("fueltrack.reminder."))
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    @MainActor
    static func cancelAllComplianceNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter {
            $0.hasPrefix("fueltrack.compliance.") || $0.hasPrefix("fueltrack.reminder.")
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
