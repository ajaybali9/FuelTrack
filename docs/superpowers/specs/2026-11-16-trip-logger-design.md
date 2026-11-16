# Trip Logger Design

**Date:** 2026-11-16  
**Status:** Draft for review  
**App:** FuelTrack (SwiftUI + SwiftData, iPhone)

## Goal

Add a GPS Trip Logger so the driver can start a trip, track distance/speed (and estimated economy) in the background, end the trip, and later open a history entry with the stored route path.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Tracking | Background GPS while trip is active |
| Economy | Estimated MPG / L/100km from vehicle `FuelStats` average × GPS distance |
| Placement | Home quick-access card + history under More |
| Route storage | Full GPS path for history map; no live map while recording (v1) |
| Architecture | Dedicated `TripRecorder` separate from station `LocationProvider` |
| Pause | Out of v1 (start / end only) |

## Feature tree

```
Trip Logger
├── Permissions & system
│   ├── When-In-Use location (existing stations copy refreshed)
│   ├── Always location (trip background)
│   ├── UIBackgroundModes = location
│   └── Settings deep-link when denied
├── Data
│   ├── Trip (summary + status)
│   ├── TripPoint (ordered path samples)
│   ├── Vehicle.trips relationship
│   └── Schema registration in FuelTrackApp
├── Recording engine
│   ├── TripRecorder (start / end / resume)
│   ├── Continuous CLLocation updates
│   ├── Accuracy / jump filters
│   ├── Live stats recompute
│   └── Incremental SwiftData persistence
├── Stats
│   ├── Distance (vehicle odometer unit)
│   ├── Current / average / max speed
│   ├── Duration
│   └── Estimated MPG & L/100km (nil if no fuel average)
├── Home UX
│   ├── HomeTripCard (idle / active / interrupted)
│   ├── Start Trip
│   ├── ActiveTripView (stats-first, no live map)
│   └── End Trip (+ discard if ~0 distance)
├── History UX
│   ├── More → Trip Logger list
│   ├── TripDetailView summary
│   └── MapKit polyline from TripPoints
└── Resilience
    ├── Mid-trip app kill → recoverable .active trip
    ├── Resume if Always authorized
    └── Interrupted banner → Resume / End
```

## Architecture

### Location split

- **`LocationProvider`** — unchanged role: one-shot / when-in-use for nearby stations.
- **`TripRecorder`** — owns continuous GPS, background updates, active session, live stats, and SwiftData writes for trips.

### Persistence

- On-device SwiftData only (same as v1 FuelTrack — no cloud).
- Trips belong to a `Vehicle` (active vehicle for start; history filtered to active vehicle).
- One active trip per vehicle at a time.

### UI placement

- **Home:** `HomeTripCard` for start / live summary / end entry point.
- **More → Trip Logger:** completed trip list and detail map.
- Tab bar stays: Home, Fuel, Spend, Stations, More.

## Data model

### `Trip`

| Field | Notes |
|-------|--------|
| `id: UUID` | |
| `startedAt: Date` | |
| `endedAt: Date?` | nil while active |
| `statusRaw: String` | `active` / `completed` / `cancelled` |
| `distance: Double` | in vehicle `odometerUnit` |
| `durationSeconds: Double` | |
| `averageSpeed: Double` | same distance unit per hour |
| `maxSpeed: Double` | |
| `estimatedMPG: Double?` | from FuelStats × distance |
| `estimatedLitersPer100km: Double?` | |
| `startLatitude/Longitude` | first accepted point |
| `endLatitude/Longitude` | last accepted point |
| `note: String` | optional; empty default |
| `createdAt: Date` | |
| `vehicle: Vehicle?` | inverse relationship |
| `points: [TripPoint]` | cascade delete |

### `TripPoint`

| Field | Notes |
|-------|--------|
| `id: UUID` | |
| `recordedAt: Date` | |
| `latitude: Double` | |
| `longitude: Double` | |
| `speedMps: Double?` | from CLLocation when available |
| `horizontalAccuracy: Double?` | metres |
| `sequence: Int` | ordered index within trip |
| `trip: Trip?` | |

### `Vehicle` change

- Add `@Relationship(deleteRule: .cascade, inverse: \Trip.vehicle) var trips: [Trip]`.

## Components

| Unit | Responsibility |
|------|----------------|
| `TripRecorder` | Session lifecycle, CLLocationManager (background), append points, update trip fields |
| `TripStats` | Pure distance / speed / duration / estimated economy helpers (unit-testable / smoke script) |
| `HomeTripCard` | Dashboard affordance: idle Start, active live chips, interrupted Resume/End |
| `ActiveTripView` | Full live stats screen (distance, speeds, duration, est. economy) |
| `TripListView` | More → history for active vehicle |
| `TripDetailView` | Summary + MapKit polyline |
| `FuelTrackApp` | Register models; inject `TripRecorder` in environment |
| `Info.plist` | Always usage string; background location mode; refresh when-in-use copy |

## Data flow & lifecycle

### Start

1. Require active vehicle.
2. Request location authorization (When-In-Use, then Always for background).
3. Create `Trip(status: .active)` on that vehicle.
4. Start continuous updates; present active UI.

### During

1. Accept GPS samples that pass accuracy / anti-jump filters.
2. Append `TripPoint`; update distance, current/avg/max speed, duration, estimated economy.
3. Persist incrementally (not only on End).

### End

1. Stop updates; set `endedAt` and final aggregates; `status = .completed`.
2. If distance ≈ 0, offer Discard (`cancelled` or delete) vs Keep.
3. Home card returns to idle; trip appears in history.

### App kill / relaunch

1. On launch, query for `status == .active`.
2. If Always authorized → resume recording.
3. Else → Home card “Trip interrupted” with Resume / End.

### Pause

- Not in v1.

## Estimated economy

- Source: `FuelStats.compute(vehicle:).averageMPG` and `averageLitersPer100km`.
- Apply the vehicle’s known average rates to the trip’s GPS distance (display-only estimate; does not invent litres burned from GPS alone).
- If averages are nil → show “—” for economy fields; still show distance and speed.

## Error handling

| Case | Behaviour |
|------|-----------|
| Location denied | Block Start; message + open Settings |
| When-In-Use only | Allow Start; banner that background needs Always; updates pause in background; Resume/End on return |
| Poor GPS / jumps | Drop bad points; do not inflate distance |
| No fuel history | Economy “—” |
| No active vehicle | Disable/hide Start |
| Tiny trip on End | Confirm Discard vs Keep |

## Backup

- Prefer including `Trip` / `TripPoint` in FuelTrack JSON backup in the same feature work (bump backup format version).
- If backup expansion slips, trips remain on-device in SwiftData and are documented as “not in backup yet” until the version bump ships — do not silently drop trips on restore.

## Testing

1. **`Scripts/tripstats-smoke.swift`** — distance between points, avg/max speed, estimated MPG from a mock vehicle average.
2. **Device manual** — Start → lock/background → return → End → open history map polyline.
3. **Schema** — cold launch with new models; existing fill-ups/vehicles intact.
4. **Interrupted trip** — force-quit mid-trip → relaunch → Resume or End.

## Out of scope (v1)

- Live map during recording
- Pause / resume button (beyond interrupted recovery)
- CarPlay / Android Auto
- Cloud sync of trips
- Manual fuel-used entry for true trip MPG
- Trip export as GPX (nice-to-have later)

## Implementation phases (tree → build order)

```
Phase 1 — Foundation
  ├── Trip + TripPoint models + Vehicle relationship
  ├── Schema registration
  └── TripStats + smoke script

Phase 2 — Recorder
  ├── TripRecorder + background location plist
  ├── Start / End / relaunch resume
  └── Point filtering + incremental save

Phase 3 — Home UX
  ├── HomeTripCard on Dashboard
  └── ActiveTripView

Phase 4 — History UX
  ├── More → TripListView
  └── TripDetailView + polyline map

Phase 5 — Polish
  ├── Backup version bump (trips in/out)
  ├── Empty / permission / discard states
  └── Device verification checklist
```

## Success criteria

- User can start a trip from Home, leave the app, return, and still see an updating (or cleanly interrupted) session.
- Ending a trip stores distance, duration, speeds, estimated economy (when fuel averages exist), and a path that draws on the detail map.
- History under More lists past trips for the active vehicle.
- Station nearby GPS behaviour remains unchanged.
