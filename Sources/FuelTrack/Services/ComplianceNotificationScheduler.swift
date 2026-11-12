import Foundation
import UserNotifications

enum ComplianceNotificationScheduler {
    private static let enabledKey = "complianceNotificationsEnabled"
    /// Notify this many days before expiry (inclusive window).
    static let leadDays = [4, 3]

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
        }
    }

    @MainActor
    static func reschedule(for vehicle: Vehicle) async {
        await cancel(for: vehicle)
        guard isEnabled else { return }
        let allowed = await requestAuthorizationIfNeeded()
        guard allowed else { return }
        await schedule(for: vehicle, center: .current())
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
                guard let contentDate = notificationDate(daysBefore: days, dueDate: due) else { continue }

                let dayLabel = days == 1 ? "1 day" : "\(days) days"
                let content = UNMutableNotificationContent()
                content.title = "\(item.title) due soon"
                content.body = "\(plate) · \(item.title) expires in \(dayLabel) (\(Formatters.shortDate(due)))."
                content.sound = .default
                content.userInfo = [
                    "vehicleId": vehicle.id.uuidString,
                    "kind": item.kind,
                    "daysBefore": days,
                ]

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: contentDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let id = notificationID(vehicleID: vehicle.id, kind: item.kind, daysBefore: days)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    /// 9:00 local on the calendar day that is `daysBefore` the due date.
    private static func notificationDate(daysBefore: Int, dueDate: Date, now: Date = .now) -> Date? {
        let calendar = Calendar.current
        let dueDay = calendar.startOfDay(for: dueDate)
        guard let fireDay = calendar.date(byAdding: .day, value: -daysBefore, to: dueDay) else { return nil }
        var parts = calendar.dateComponents([.year, .month, .day], from: fireDay)
        parts.hour = 9
        parts.minute = 0
        guard let fire = calendar.date(from: parts), fire > now else { return nil }
        return fire
    }

    private static func notificationID(vehicleID: UUID, kind: String, daysBefore: Int) -> String {
        "fueltrack.compliance.\(vehicleID.uuidString).\(kind).d\(daysBefore)"
    }

    @MainActor
    static func cancel(for vehicle: Vehicle) async {
        let center = UNUserNotificationCenter.current()
        let kinds = ["mot", "tax", "insurance"]
        var ids: [String] = []
        for kind in kinds {
            for days in leadDays {
                ids.append(notificationID(vehicleID: vehicle.id, kind: kind, daysBefore: days))
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    @MainActor
    static func cancelAllComplianceNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("fueltrack.compliance.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
