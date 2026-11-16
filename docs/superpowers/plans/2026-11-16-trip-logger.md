# Trip Logger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a background GPS Trip Logger with Home start/end, live stats, estimated economy from FuelStats, SwiftData history, and a path map under More.

**Architecture:** Keep station `LocationProvider` one-shot. Add `TripRecorder` for continuous/background GPS, `Trip` + `TripPoint` SwiftData models on `Vehicle`, Home card + ActiveTripView for live UX, More → list/detail with MapKit polyline. Estimated MPG/L/100km are snapshots of the vehicle’s FuelStats averages applied to the trip.

**Tech Stack:** SwiftUI, SwiftData, CoreLocation (background), MapKit, existing GlassTheme / Formatters / FuelStats.

**Spec:** `docs/superpowers/specs/2026-11-16-trip-logger-design.md`

## Global Constraints

- iOS app via xtool; sources under `Sources/FuelTrack/`
- On-device SwiftData only; no cloud
- Do not break nearby-stations `LocationProvider` behaviour
- One active trip per vehicle; active vehicle drives Home start
- No live map while recording; no pause button in v1
- Backup format version must bump to include trips
- Verify pure helpers with `swift Scripts/*.swift` smoke scripts when available

## File map

| Path | Role |
|------|------|
| `Sources/FuelTrack/Models/TripStatus.swift` | `active` / `completed` / `cancelled` |
| `Sources/FuelTrack/Models/Trip.swift` | Trip summary model |
| `Sources/FuelTrack/Models/TripPoint.swift` | Path sample model |
| `Sources/FuelTrack/Models/Vehicle.swift` | Add `trips` relationship |
| `Sources/FuelTrack/Support/IdentifiableModels.swift` | Identifiable for Trip |
| `Sources/FuelTrack/Services/TripStats.swift` | Pure distance/speed/economy helpers |
| `Sources/FuelTrack/Services/TripRecorder.swift` | Continuous GPS + session lifecycle |
| `Sources/FuelTrack/Services/Formatters.swift` | Speed / duration formatters |
| `Sources/FuelTrack/FuelTrackApp.swift` | Schema + inject TripRecorder |
| `Support/Info.plist` | Always + background location |
| `Sources/FuelTrack/Views/Trips/HomeTripCard.swift` | Home card |
| `Sources/FuelTrack/Views/Trips/ActiveTripView.swift` | Live stats screen |
| `Sources/FuelTrack/Views/Trips/TripListView.swift` | History list |
| `Sources/FuelTrack/Views/Trips/TripDetailView.swift` | Summary + polyline |
| `Sources/FuelTrack/Views/Dashboard/DashboardView.swift` | Embed HomeTripCard |
| `Sources/FuelTrack/Views/More/MoreView.swift` | Link to TripListView |
| `Sources/FuelTrack/Services/FuelTrackBackupExporter.swift` | v2 + trip backup types |
| `Sources/FuelTrack/Services/FuelTrackBackupImporter.swift` | Import trips |
| `Scripts/tripstats-smoke.swift` | TripStats smoke |
| `Scripts/backup-roundtrip-smoke.swift` | Include trips in v2 shape |
| `rea-target/FUELIO_FEATURE_MAP.md` | Mark GPS Trip log mirrored |

---

### Task 1: Trip models + Vehicle relationship

**Files:**
- Create: `Sources/FuelTrack/Models/TripStatus.swift`
- Create: `Sources/FuelTrack/Models/Trip.swift`
- Create: `Sources/FuelTrack/Models/TripPoint.swift`
- Modify: `Sources/FuelTrack/Models/Vehicle.swift`
- Modify: `Sources/FuelTrack/Support/IdentifiableModels.swift`
- Modify: `Sources/FuelTrack/FuelTrackApp.swift`

**Interfaces:**
- Produces: `TripStatus`, `Trip`, `TripPoint`; `Vehicle.trips`; schema includes both models

- [ ] **Step 1: Add `TripStatus`**

```swift
import Foundation

enum TripStatus: String, CaseIterable, Codable, Sendable {
    case active
    case completed
    case cancelled
}
```

- [ ] **Step 2: Add `TripPoint`**

```swift
import Foundation
import SwiftData

@Model
final class TripPoint {
    var id: UUID
    var recordedAt: Date
    var latitude: Double
    var longitude: Double
    var speedMps: Double?
    var horizontalAccuracy: Double?
    var sequence: Int
    var trip: Trip?

    init(
        id: UUID = UUID(),
        recordedAt: Date = .now,
        latitude: Double,
        longitude: Double,
        speedMps: Double? = nil,
        horizontalAccuracy: Double? = nil,
        sequence: Int,
        trip: Trip? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.latitude = latitude
        self.longitude = longitude
        self.speedMps = speedMps
        self.horizontalAccuracy = horizontalAccuracy
        self.sequence = sequence
        self.trip = trip
    }
}
```

- [ ] **Step 3: Add `Trip`**

```swift
import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var statusRaw: String
    var distance: Double
    var durationSeconds: Double
    var averageSpeed: Double
    var maxSpeed: Double
    var estimatedMPG: Double?
    var estimatedLitersPer100km: Double?
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var note: String
    var createdAt: Date

    var vehicle: Vehicle?

    @Relationship(deleteRule: .cascade, inverse: \TripPoint.trip)
    var points: [TripPoint]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        status: TripStatus = .active,
        distance: Double = 0,
        durationSeconds: Double = 0,
        averageSpeed: Double = 0,
        maxSpeed: Double = 0,
        estimatedMPG: Double? = nil,
        estimatedLitersPer100km: Double? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        note: String = "",
        createdAt: Date = .now,
        vehicle: Vehicle? = nil,
        points: [TripPoint] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.statusRaw = status.rawValue
        self.distance = distance
        self.durationSeconds = durationSeconds
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.estimatedMPG = estimatedMPG
        self.estimatedLitersPer100km = estimatedLitersPer100km
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.note = note
        self.createdAt = createdAt
        self.vehicle = vehicle
        self.points = points
    }

    var status: TripStatus {
        get { TripStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    var sortedPoints: [TripPoint] {
        points.sorted { $0.sequence < $1.sequence }
    }
}
```

- [ ] **Step 4: Wire `Vehicle.trips` and init default**

In `Vehicle.swift`, add relationship after `savedStations`:

```swift
@Relationship(deleteRule: .cascade, inverse: \Trip.vehicle)
var trips: [Trip]
```

Add `trips: [Trip] = []` to `init` parameters and `self.trips = trips` in the body.

Add helper:

```swift
var sortedTrips: [Trip] {
    trips
        .filter { $0.status == .completed }
        .sorted { $0.startedAt > $1.startedAt }
}

var activeTrip: Trip? {
    trips.first { $0.status == .active }
}
```

- [ ] **Step 5: Identifiable + schema**

`IdentifiableModels.swift`:

```swift
extension Trip: Identifiable {}
extension TripPoint: Identifiable {}
```

`FuelTrackApp.swift` schema array — append `Trip.self, TripPoint.self`.

Also create `TripRecorder` environment placeholder in the same file only after Task 3; for this task only register models:

```swift
let schema = Schema([
    Vehicle.self,
    FillUp.self,
    CarCost.self,
    ReminderItem.self,
    PersonalExpense.self,
    PersonalBudget.self,
    CustomExpenseCategory.self,
    SavedStation.self,
    Trip.self,
    TripPoint.self,
])
```

- [ ] **Step 6: Commit**

```bash
git add Sources/FuelTrack/Models/TripStatus.swift \
  Sources/FuelTrack/Models/Trip.swift \
  Sources/FuelTrack/Models/TripPoint.swift \
  Sources/FuelTrack/Models/Vehicle.swift \
  Sources/FuelTrack/Support/IdentifiableModels.swift \
  Sources/FuelTrack/FuelTrackApp.swift
git commit -m "feat: add Trip and TripPoint SwiftData models"
```

---

### Task 2: TripStats helpers + smoke script

**Files:**
- Create: `Sources/FuelTrack/Services/TripStats.swift`
- Create: `Scripts/tripstats-smoke.swift`

**Interfaces:**
- Consumes: `OdometerUnit` formulas (duplicated in smoke script)
- Produces: `TripStats.distanceMeters`, `distanceInUnit`, `averageSpeed`, `maxSpeed`, `durationSeconds`, `estimatedEconomy`

- [ ] **Step 1: Write failing smoke script first**

Create `Scripts/tripstats-smoke.swift` with copied helpers (same pattern as `fuelstats-smoke.swift`):

```swift
#!/usr/bin/env swift
import Foundation

enum OdometerUnit {
    case miles, kilometers
    func fromKilometers(_ kilometers: Double) -> Double {
        switch self {
        case .miles: kilometers / 1.609344
        case .kilometers: kilometers
        }
    }
}

struct Sample {
    var latitude: Double
    var longitude: Double
    var recordedAt: Date
    var speedMps: Double?
}

func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let r = 6_371_000.0
    let φ1 = lat1 * .pi / 180
    let φ2 = lat2 * .pi / 180
    let Δφ = (lat2 - lat1) * .pi / 180
    let Δλ = (lon2 - lon1) * .pi / 180
    let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
    return 2 * r * atan2(sqrt(a), sqrt(1 - a))
}

func distanceMeters(_ samples: [Sample]) -> Double {
    guard samples.count >= 2 else { return 0 }
    var total = 0.0
    for i in 1..<samples.count {
        total += haversineMeters(
            lat1: samples[i - 1].latitude, lon1: samples[i - 1].longitude,
            lat2: samples[i].latitude, lon2: samples[i].longitude
        )
    }
    return total
}

func durationSeconds(from samples: [Sample], endedAt: Date? = nil) -> Double {
    guard let first = samples.first else { return 0 }
    let end = endedAt ?? samples.last?.recordedAt ?? first.recordedAt
    return max(0, end.timeIntervalSince(first.recordedAt))
}

func averageSpeed(distance: Double, durationSeconds: Double) -> Double {
    guard durationSeconds > 0 else { return 0 }
    return distance / (durationSeconds / 3600)
}

/// metres/sec → mi/h or km/h (numeric km/h treated as km magnitude for unit conversion).
func speedInUnit(mps: Double, unit: OdometerUnit) -> Double {
    let kmh = mps * 3.6
    return unit.fromKilometers(kmh)
}

func estimatedEconomy(averageMPG: Double?, averageL100: Double?) -> (mpg: Double?, l100: Double?) {
    (averageMPG, averageL100)
}

let t0 = Date(timeIntervalSince1970: 1_700_000_000)
let samples = [
    Sample(latitude: 51.5074, longitude: -0.1278, recordedAt: t0, speedMps: 10),
    Sample(latitude: 51.5174, longitude: -0.1278, recordedAt: t0.addingTimeInterval(600), speedMps: 20),
]
let metres = distanceMeters(samples)
assert(metres > 1000 && metres < 1200) // ~1.11 km north
let unit = OdometerUnit.miles
let distance = unit.fromKilometers(metres / 1000)
let duration = durationSeconds(from: samples)
assert(abs(duration - 600) < 0.001)
let avg = averageSpeed(distance: distance, durationSeconds: duration)
assert(avg > 0)
let maxS = samples.compactMap(\.speedMps).map { speedInUnit(mps: $0, unit: unit) }.max()!
assert(abs(maxS - speedInUnit(mps: 20, unit: .miles)) < 0.001)
let eco = estimatedEconomy(averageMPG: 40, averageL100: 7.0)
assert(eco.mpg == 40 && eco.l100 == 7.0)
print("tripstats-smoke: PASS (metres=\(Int(metres)), avgMph=\(String(format: "%.1f", avg)))")
```

- [ ] **Step 2: Run smoke — expect PASS once helpers match (script is self-contained)**

```bash
swift Scripts/tripstats-smoke.swift
```

Expected: `tripstats-smoke: PASS ...`

- [ ] **Step 3: Implement app `TripStats.swift` mirroring the smoke formulas**

```swift
import CoreLocation
import Foundation

enum TripStats {
    static let minimumHorizontalAccuracyMeters: Double = 50
    static let maximumJumpMeters: Double = 200

    static func haversineMeters(
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) -> Double {
        let r = 6_371_000.0
        let φ1 = a.latitude * .pi / 180
        let φ2 = b.latitude * .pi / 180
        let Δφ = (b.latitude - a.latitude) * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let sinΔφ = sin(Δφ / 2)
        let sinΔλ = sin(Δλ / 2)
        let h = sinΔφ * sinΔφ + cos(φ1) * cos(φ2) * sinΔλ * sinΔλ
        return 2 * r * atan2(sqrt(h), sqrt(1 - h))
    }

    static func shouldAccept(
        location: CLLocation,
        previous: CLLocation?
    ) -> Bool {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= minimumHorizontalAccuracyMeters
        else { return false }
        guard let previous else { return true }
        let jump = location.distance(from: previous)
        return jump <= maximumJumpMeters
    }

    static func distanceInUnit(metres: Double, unit: OdometerUnit) -> Double {
        unit.fromKilometers(metres / 1000)
    }

    /// Convert m/s to miles-per-hour or km-per-hour.
    static func speedInUnit(metersPerSecond: Double, unit: OdometerUnit) -> Double {
        let kmh = metersPerSecond * 3.6
        return unit.fromKilometers(kmh)
    }

    static func averageSpeed(distance: Double, durationSeconds: Double) -> Double {
        guard durationSeconds > 0 else { return 0 }
        return distance / (durationSeconds / 3600)
    }

    static func durationSeconds(startedAt: Date, endedAt: Date) -> Double {
        max(0, endedAt.timeIntervalSince(startedAt))
    }

    /// Snapshot vehicle FuelStats averages onto the trip (estimate, not GPS-derived burn).
    static func estimatedEconomy(
        averageMPG: Double?,
        averageLitersPer100km: Double?
    ) -> (mpg: Double?, litersPer100km: Double?) {
        (averageMPG, averageLitersPer100km)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add Sources/FuelTrack/Services/TripStats.swift Scripts/tripstats-smoke.swift
git commit -m "feat: add TripStats helpers and smoke script"
```

---

### Task 3: TripRecorder + Info.plist + app injection

**Files:**
- Create: `Sources/FuelTrack/Services/TripRecorder.swift`
- Modify: `Support/Info.plist`
- Modify: `Sources/FuelTrack/FuelTrackApp.swift`

**Interfaces:**
- Consumes: `Trip`, `TripPoint`, `TripStats`, `Vehicle`, `ModelContext`
- Produces: `TripRecorder.start/end/discard/restoreActiveTripIfNeeded`; live published fields

- [ ] **Step 1: Update `Support/Info.plist`**

Replace location usage strings and add Always + background:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>FuelTrack uses your location to find nearby petrol stations and to record GPS trip logs.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>FuelTrack needs background location while a trip is active so distance and speed keep updating when the phone is locked.</string>
<key>NSLocationUsageDescription</key>
<string>FuelTrack uses your location to find nearby petrol stations and to record GPS trip logs.</string>
<key>UIBackgroundModes</key>
<array>
	<string>location</string>
</array>
```

(Remove the old Always-less-only copy; keep When-In-Use key.)

- [ ] **Step 2: Implement `TripRecorder`**

```swift
import CoreLocation
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TripRecorder: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var modelContext: ModelContext?
    private var lastAcceptedLocation: CLLocation?
    private var nextSequence = 0
    private var economyMPG: Double?
    private var economyL100: Double?
    private var unit: OdometerUnit = .miles

    private(set) var activeTrip: Trip?
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var lastError: String?
    private(set) var isRecording = false
    /// True when trip is active but only When-In-Use was granted.
    private(set) var backgroundLimited = false

    var currentSpeed: Double = 0
    var liveDistance: Double = 0
    var liveDurationSeconds: Double = 0
    var liveAverageSpeed: Double = 0
    var liveMaxSpeed: Double = 0
    var liveEstimatedMPG: Double?
    var liveEstimatedL100: Double?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.showsBackgroundLocationIndicator = true
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var isAuthorizedWhenInUseOrBetter: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: true
        default: false
        }
    }

    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }

    func requestWhenInUse() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysIfNeeded() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    func restoreActiveTripIfNeeded(for vehicle: Vehicle) {
        guard let trip = vehicle.activeTrip else { return }
        activeTrip = trip
        unit = vehicle.odometerUnit
        economyMPG = trip.estimatedMPG
        economyL100 = trip.estimatedLitersPer100km
        nextSequence = (trip.points.map(\.sequence).max() ?? -1) + 1
        liveDistance = trip.distance
        liveMaxSpeed = trip.maxSpeed
        liveEstimatedMPG = trip.estimatedMPG
        liveEstimatedL100 = trip.estimatedLitersPer100km
        refreshLiveDuration()
        if isAuthorizedWhenInUseOrBetter {
            beginUpdates()
        }
    }

    @discardableResult
    func start(
        vehicle: Vehicle,
        averageMPG: Double?,
        averageLitersPer100km: Double?
    ) -> Bool {
        guard vehicle.activeTrip == nil else {
            restoreActiveTripIfNeeded(for: vehicle)
            return activeTrip != nil
        }
        guard let modelContext else {
            lastError = "Trip storage isn’t ready."
            return false
        }
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            lastError = "Allow location access to start a trip."
            return false
        }
        guard isAuthorizedWhenInUseOrBetter else {
            lastError = "Location access is required to start a trip."
            return false
        }

        unit = vehicle.odometerUnit
        let eco = TripStats.estimatedEconomy(
            averageMPG: averageMPG,
            averageLitersPer100km: averageLitersPer100km
        )
        economyMPG = eco.mpg
        economyL100 = eco.litersPer100km

        let trip = Trip(
            status: .active,
            estimatedMPG: eco.mpg,
            estimatedLitersPer100km: eco.litersPer100km,
            vehicle: vehicle
        )
        modelContext.insert(trip)
        try? modelContext.save()

        activeTrip = trip
        lastAcceptedLocation = nil
        nextSequence = 0
        liveDistance = 0
        liveMaxSpeed = 0
        currentSpeed = 0
        liveAverageSpeed = 0
        liveDurationSeconds = 0
        liveEstimatedMPG = eco.mpg
        liveEstimatedL100 = eco.litersPer100km
        lastError = nil
        beginUpdates()
        return true
    }

    func end(keepEmptyTrip: Bool = false) {
        guard let trip = activeTrip, let modelContext else { return }
        stopUpdates()
        finalizeLiveFields(on: trip)
        if trip.distance < 0.05 && !keepEmptyTrip {
            modelContext.delete(trip)
        } else {
            trip.status = .completed
            trip.endedAt = .now
        }
        try? modelContext.save()
        clearSession()
    }

    func discard() {
        guard let trip = activeTrip, let modelContext else { return }
        stopUpdates()
        modelContext.delete(trip)
        try? modelContext.save()
        clearSession()
    }

    private func beginUpdates() {
        backgroundLimited = !hasAlwaysAuthorization
        manager.allowsBackgroundLocationUpdates = hasAlwaysAuthorization
        manager.startUpdatingLocation()
        isRecording = true
        if authorizationStatus == .authorizedWhenInUse {
            requestAlwaysIfNeeded()
        }
    }

    private func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isRecording = false
    }

    private func clearSession() {
        activeTrip = nil
        lastAcceptedLocation = nil
        nextSequence = 0
        liveDistance = 0
        liveDurationSeconds = 0
        liveAverageSpeed = 0
        liveMaxSpeed = 0
        currentSpeed = 0
        liveEstimatedMPG = nil
        liveEstimatedL100 = nil
        backgroundLimited = false
    }

    private func refreshLiveDuration() {
        guard let trip = activeTrip else { return }
        liveDurationSeconds = TripStats.durationSeconds(startedAt: trip.startedAt, endedAt: .now)
        liveAverageSpeed = TripStats.averageSpeed(distance: liveDistance, durationSeconds: liveDurationSeconds)
    }

    private func finalizeLiveFields(on trip: Trip) {
        refreshLiveDuration()
        trip.distance = liveDistance
        trip.durationSeconds = liveDurationSeconds
        trip.averageSpeed = liveAverageSpeed
        trip.maxSpeed = liveMaxSpeed
        trip.estimatedMPG = liveEstimatedMPG
        trip.estimatedLitersPer100km = liveEstimatedL100
        if let last = trip.sortedPoints.last {
            trip.endLatitude = last.latitude
            trip.endLongitude = last.longitude
        }
    }

    private func accept(_ location: CLLocation) {
        guard let trip = activeTrip, let modelContext else { return }
        guard TripStats.shouldAccept(location: location, previous: lastAcceptedLocation) else { return }

        if let previous = lastAcceptedLocation {
            let delta = location.distance(from: previous)
            liveDistance += TripStats.distanceInUnit(metres: delta, unit: unit)
        } else {
            trip.startLatitude = location.coordinate.latitude
            trip.startLongitude = location.coordinate.longitude
        }

        let point = TripPoint(
            recordedAt: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speedMps: location.speed >= 0 ? location.speed : nil,
            horizontalAccuracy: location.horizontalAccuracy,
            sequence: nextSequence,
            trip: trip
        )
        nextSequence += 1
        modelContext.insert(point)

        if location.speed >= 0 {
            let speed = TripStats.speedInUnit(metersPerSecond: location.speed, unit: unit)
            currentSpeed = speed
            liveMaxSpeed = max(liveMaxSpeed, speed)
        }

        refreshLiveDuration()
        trip.distance = liveDistance
        trip.durationSeconds = liveDurationSeconds
        trip.averageSpeed = liveAverageSpeed
        trip.maxSpeed = liveMaxSpeed
        trip.endLatitude = location.coordinate.latitude
        trip.endLongitude = location.coordinate.longitude
        try? modelContext.save()
        lastAcceptedLocation = location
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if self.activeTrip != nil, self.isAuthorizedWhenInUseOrBetter {
                self.beginUpdates()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.accept(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.lastError = message
        }
    }
}
```

- [ ] **Step 3: Inject in `FuelTrackApp`**

```swift
private let tripRecorder = TripRecorder()

// in body:
ContentView()
    .environment(activeVehicleStore)
    .environment(locationProvider)
    .environment(tripRecorder)
```

- [ ] **Step 4: Commit**

```bash
git add Sources/FuelTrack/Services/TripRecorder.swift \
  Support/Info.plist \
  Sources/FuelTrack/FuelTrackApp.swift
git commit -m "feat: add TripRecorder with background location support"
```

---

### Task 4: Formatters + Home / Active trip UI

**Files:**
- Modify: `Sources/FuelTrack/Services/Formatters.swift`
- Create: `Sources/FuelTrack/Views/Trips/HomeTripCard.swift`
- Create: `Sources/FuelTrack/Views/Trips/ActiveTripView.swift`
- Modify: `Sources/FuelTrack/Views/Dashboard/DashboardView.swift`
- Modify: `Sources/FuelTrack/Views/ContentView.swift` (attach modelContext to recorder on appear)

**Interfaces:**
- Consumes: `TripRecorder`, `FuelStats`, `Vehicle`
- Produces: Home start/end UX; ActiveTripView

- [ ] **Step 1: Add formatters**

```swift
static func tripSpeed(_ value: Double, unit: OdometerUnit) -> String {
    String(format: "%.0f %@/h", value, unit.shortLabel)
}

static func tripDistance(_ value: Double, unit: OdometerUnit) -> String {
    String(format: "%.2f %@", value, unit.shortLabel)
}

static func tripDuration(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}
```

- [ ] **Step 2: Create `HomeTripCard`**

```swift
import SwiftData
import SwiftUI

struct HomeTripCard: View {
    let vehicle: Vehicle

    @Environment(TripRecorder.self) private var tripRecorder
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var showActive = false
    @State private var confirmEnd = false

    private var isThisVehicleActive: Bool {
        tripRecorder.activeTrip?.vehicle?.id == vehicle.id
            || vehicle.activeTrip != nil
    }

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Trip Logger", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.headline)
                    Spacer()
                    if tripRecorder.isRecording && isThisVehicleActive {
                        Text("LIVE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GlassTheme.accentWarm)
                    }
                }

                if let error = tripRecorder.lastError, !isThisVehicleActive {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if isThisVehicleActive {
                    liveBlock
                } else {
                    Text("Track distance, speed, and estimated MPG from your fuel log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        start()
                    } label: {
                        Text("Start trip")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GlassTheme.accent)
                }
            }
        }
        .onAppear {
            tripRecorder.attach(modelContext: modelContext)
            tripRecorder.restoreActiveTripIfNeeded(for: vehicle)
        }
        .sheet(isPresented: $showActive) {
            NavigationStack {
                ActiveTripView(vehicle: vehicle)
            }
        }
        .confirmationDialog("End trip?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End trip", role: .destructive) {
                tripRecorder.end(keepEmptyTrip: false)
            }
            Button("Discard trip", role: .destructive) {
                tripRecorder.discard()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var liveBlock: some View {
        if tripRecorder.backgroundLimited {
            Text("Background tracking needs Always location. Open Settings if the trip pauses when locked.")
                .font(.caption2)
                .foregroundStyle(.orange)
        }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            GlassStatChip(title: "Distance", value: Formatters.tripDistance(tripRecorder.liveDistance, unit: vehicle.odometerUnit))
            GlassStatChip(title: "Speed", value: Formatters.tripSpeed(tripRecorder.currentSpeed, unit: vehicle.odometerUnit))
            GlassStatChip(title: "Avg", value: Formatters.tripSpeed(tripRecorder.liveAverageSpeed, unit: vehicle.odometerUnit))
            GlassStatChip(
                title: "Est. MPG",
                value: Formatters.consumptionMPG(tripRecorder.liveEstimatedMPG),
                tint: GlassTheme.accentWarm
            )
        }

        HStack {
            Button("Open") { showActive = true }
                .buttonStyle(.bordered)
            Button("End trip") { confirmEnd = true }
                .buttonStyle(.borderedProminent)
                .tint(GlassTheme.accentWarm)
            if !tripRecorder.hasAlwaysAuthorization {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.caption)
            }
        }
    }

    private func start() {
        tripRecorder.attach(modelContext: modelContext)
        let stats = FuelStats.compute(vehicle: vehicle)
        let ok = tripRecorder.start(
            vehicle: vehicle,
            averageMPG: stats.averageMPG,
            averageLitersPer100km: stats.averageLitersPer100km
        )
        if ok { showActive = true }
    }
}
```

- [ ] **Step 3: Create `ActiveTripView`**

Stats-first screen (no map): distance, duration, current/avg/max speed, est. MPG and L/100km, End button with same confirmation. Use `TimelineView(.periodic(from: .now, by: 1))` to refresh duration display via `tripRecorder` live fields (recorder already updates on GPS; call a lightweight `onAppear` timer if needed — prefer reading `tripRecorder.liveDurationSeconds` and relying on location ticks; optional `Timer` publish every 1s inside recorder is acceptable if duration feels sticky).

Minimal body:

```swift
import SwiftUI

struct ActiveTripView: View {
    let vehicle: Vehicle
    @Environment(TripRecorder.self) private var tripRecorder
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEnd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(Formatters.tripDistance(tripRecorder.liveDistance, unit: vehicle.odometerUnit))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(Formatters.tripDuration(tripRecorder.liveDurationSeconds))
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    GlassStatChip(title: "Current", value: Formatters.tripSpeed(tripRecorder.currentSpeed, unit: vehicle.odometerUnit))
                    GlassStatChip(title: "Average", value: Formatters.tripSpeed(tripRecorder.liveAverageSpeed, unit: vehicle.odometerUnit))
                    GlassStatChip(title: "Max", value: Formatters.tripSpeed(tripRecorder.liveMaxSpeed, unit: vehicle.odometerUnit))
                    GlassStatChip(title: "Est. MPG", value: Formatters.consumptionMPG(tripRecorder.liveEstimatedMPG), tint: GlassTheme.accentWarm)
                    GlassStatChip(title: "Est. L/100", value: Formatters.consumptionL100(tripRecorder.liveEstimatedL100))
                }
            }
            .padding()
        }
        .navigationTitle("Active trip")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackScreen()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("End") { confirmEnd = true }
            }
        }
        .confirmationDialog("End trip?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End trip", role: .destructive) {
                tripRecorder.end(keepEmptyTrip: false)
                dismiss()
            }
            Button("Discard trip", role: .destructive) {
                tripRecorder.discard()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: tripRecorder.activeTrip?.id) { _, newValue in
            if newValue == nil { dismiss() }
        }
    }
}
```

- [ ] **Step 4: Embed card on Dashboard**

In `vehicleDashboard`, insert after the vehicle header card (before compliance):

```swift
HomeTripCard(vehicle: vehicle)
```

- [ ] **Step 5: Commit**

```bash
git add Sources/FuelTrack/Services/Formatters.swift \
  Sources/FuelTrack/Views/Trips/HomeTripCard.swift \
  Sources/FuelTrack/Views/Trips/ActiveTripView.swift \
  Sources/FuelTrack/Views/Dashboard/DashboardView.swift
git commit -m "feat: add Home trip card and active trip screen"
```

---

### Task 5: History list + detail map under More

**Files:**
- Create: `Sources/FuelTrack/Views/Trips/TripListView.swift`
- Create: `Sources/FuelTrack/Views/Trips/TripDetailView.swift`
- Modify: `Sources/FuelTrack/Views/More/MoreView.swift`

**Interfaces:**
- Consumes: `Vehicle.sortedTrips`, `Trip.sortedPoints`
- Produces: More → Trip Logger navigation

- [ ] **Step 1: `TripListView`**

```swift
import SwiftData
import SwiftUI

struct TripListView: View {
    let vehicle: Vehicle

    var body: some View {
        Group {
            if vehicle.sortedTrips.isEmpty {
                ContentUnavailableView(
                    "No trips yet",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                    description: Text("Start a trip from Home to record distance, speed, and your route.")
                )
            } else {
                List {
                    ForEach(vehicle.sortedTrips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip, unit: vehicle.odometerUnit)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Formatters.shortDate(trip.startedAt))
                                    .font(.headline)
                                Text("\(Formatters.tripDistance(trip.distance, unit: vehicle.odometerUnit)) · \(Formatters.tripDuration(trip.durationSeconds)) · \(Formatters.consumptionMPG(trip.estimatedMPG))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Trip Logger")
        .fuelTrackScreen()
    }
}
```

- [ ] **Step 2: `TripDetailView` with polyline**

```swift
import MapKit
import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    let unit: OdometerUnit

    private var coordinates: [CLLocationCoordinate2D] {
        trip.sortedPoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    GlassStatChip(title: "Distance", value: Formatters.tripDistance(trip.distance, unit: unit))
                    GlassStatChip(title: "Duration", value: Formatters.tripDuration(trip.durationSeconds))
                    GlassStatChip(title: "Avg speed", value: Formatters.tripSpeed(trip.averageSpeed, unit: unit))
                    GlassStatChip(title: "Max speed", value: Formatters.tripSpeed(trip.maxSpeed, unit: unit))
                    GlassStatChip(title: "Est. MPG", value: Formatters.consumptionMPG(trip.estimatedMPG), tint: GlassTheme.accentWarm)
                    GlassStatChip(title: "Est. L/100", value: Formatters.consumptionL100(trip.estimatedLitersPer100km))
                }

                if coordinates.count >= 2 {
                    Map {
                        MapPolyline(coordinates: coordinates)
                            .stroke(GlassTheme.accent, lineWidth: 4)
                        if let first = coordinates.first {
                            Marker("Start", coordinate: first)
                        }
                        if let last = coordinates.last {
                            Marker("End", coordinate: last)
                                .tint(GlassTheme.accentWarm)
                        }
                    }
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text("Not enough GPS points to draw this route.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackScreen()
    }
}
```

- [ ] **Step 3: More link**

After Reminders `NavigationLink`, add:

```swift
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
    moreRow("Trip Logger", subtitle: "GPS trips & routes", icon: "point.topleft.down.to.point.bottomright.curvepath")
}
```

- [ ] **Step 4: Commit**

```bash
git add Sources/FuelTrack/Views/Trips/TripListView.swift \
  Sources/FuelTrack/Views/Trips/TripDetailView.swift \
  Sources/FuelTrack/Views/More/MoreView.swift
git commit -m "feat: add trip history list and route detail map"
```

---

### Task 6: Backup v2 + Fuelio map note

**Files:**
- Modify: `Sources/FuelTrack/Services/FuelTrackBackupExporter.swift`
- Modify: `Sources/FuelTrack/Services/FuelTrackBackupImporter.swift`
- Modify: `Scripts/backup-roundtrip-smoke.swift`
- Modify: `rea-target/FUELIO_FEATURE_MAP.md`

**Interfaces:**
- Consumes: `Trip`, `TripPoint`
- Produces: `formatVersion = 2`; trips round-trip in JSON backup

- [ ] **Step 1: Bump exporter**

Set `formatVersion = 2`.

Add to `VehicleBackup`:

```swift
var trips: [TripBackup]
```

Add types:

```swift
struct TripBackup: Codable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var status: String
    var distance: Double
    var durationSeconds: Double
    var averageSpeed: Double
    var maxSpeed: Double
    var estimatedMPG: Double?
    var estimatedLitersPer100km: Double?
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var note: String
    var createdAt: Date
    var points: [TripPointBackup]
}

struct TripPointBackup: Codable, Sendable {
    var id: UUID
    var recordedAt: Date
    var latitude: Double
    var longitude: Double
    var speedMps: Double?
    var horizontalAccuracy: Double?
    var sequence: Int
}
```

In `vehicleBackup`, map trips (all statuses except optionally skip empty cancelled — include completed + any leftover):

```swift
trips: vehicle.trips
    .sorted { $0.startedAt < $1.startedAt }
    .map(tripBackup)
```

Implement `tripBackup` / `tripPointBackup` mirroring fields.

For **version 1 decode compatibility**: make `trips` default to `[]` via custom decode OR use:

```swift
var trips: [TripBackup] = []
```

and ensure `Decodable` synthesizes with default only if using explicit `init(from:)` — simplest approach: keep `trips` required in v2 exports, and in importer when decoding Snapshot, if version == 1 treat missing trips as empty by custom `VehicleBackup` decode:

```swift
init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // decode all existing fields…
    trips = try c.decodeIfPresent([TripBackup].self, forKey: .trips) ?? []
}
```

(Implement `CodingKeys` for `VehicleBackup` including `trips`.)

- [ ] **Step 2: Importer**

Extend `FuelTrackBackupImportResult` with `trips: Int` and `tripPoints: Int`; include in `summary`.

In vehicle import loop:

```swift
for trip in vehicleBackup.trips {
    upsertTrip(trip, vehicle: vehicle, into: modelContext, result: &result)
}
```

`upsertTrip` matches by `id`, replaces points on update (delete old points, insert backup points), sets all summary fields + status.

- [ ] **Step 3: Update `Scripts/backup-roundtrip-smoke.swift`**

- Set sample `version: 2`
- Add empty `trips: []` on vehicle OR one trip with two points
- Assert decode succeeds and `trips.count` matches
- Print includes trip count

Run:

```bash
swift Scripts/backup-roundtrip-smoke.swift
swift Scripts/tripstats-smoke.swift
```

Expected: both PASS.

- [ ] **Step 4: Feature map**

In `rea-target/FUELIO_FEATURE_MAP.md`, move `GPS Trip log` from “Not mirrored yet” to “Mirrored in FuelTrack now”.

- [ ] **Step 5: Commit**

```bash
git add Sources/FuelTrack/Services/FuelTrackBackupExporter.swift \
  Sources/FuelTrack/Services/FuelTrackBackupImporter.swift \
  Scripts/backup-roundtrip-smoke.swift \
  rea-target/FUELIO_FEATURE_MAP.md
git commit -m "feat: include trips in FuelTrack backup format v2"
```

---

### Task 7: Device verification checklist (manual)

**Files:** none (verification only)

- [ ] **Step 1: Build with xtool on device** (`xtool dev`) when Xcode/device available.

- [ ] **Step 2: Checklist**

1. Home → Start trip → grant location → Always prompt.
2. Active screen shows distance/speed; lock phone 1–2 minutes; unlock — distance advanced (or interrupted banner if Always denied).
3. End trip → appears under More → Trip Logger.
4. Detail shows polyline.
5. Stations tab still finds nearby pumps.
6. Export backup → JSON `version: 2` contains `trips`.
7. Force-quit mid-trip → relaunch → Resume/End on Home card.

- [ ] **Step 3: Final commit only if checklist fixes needed**; otherwise note verification results in PR body.

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| Background GPS | Task 3 |
| Estimated economy from FuelStats | Tasks 2–4 |
| Home card + More history | Tasks 4–5 |
| Full path history map | Task 5 |
| Dedicated TripRecorder | Task 3 |
| Incremental save / relaunch | Task 3 |
| Discard tiny trip | Task 3–4 |
| Backup version bump | Task 6 |
| TripStats smoke | Task 2 |
| No live map / no pause v1 | Honoured in Tasks 4–5 |

**Placeholder scan:** none intentional.  
**Type consistency:** `TripStatus` raw strings; `TripRecorder.liveEstimatedL100` ↔ `estimatedLitersPer100km`; backup `TripBackup.status` string matches `TripStatus.rawValue`.
