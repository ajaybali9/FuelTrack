# Fill-up Card Economy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show UK MPG and cost-per-distance on each Fuel Log fill-up card that closes a full-tank segment.

**Architecture:** Extend `FuelStats` with fill-up IDs on snapshots and `segmentsByEndingFillUpID(from:)`. `FillUpListView` computes the map once and passes the optional segment into `FillUpCard`, which shows a second metric row only when a segment exists.

**Tech Stack:** SwiftUI, SwiftData, existing `FuelStats` / `Formatters` / `GlassTheme` instrument chrome.

**Spec:** `docs/superpowers/specs/2026-11-21-fillup-card-economy-design.md`

## Global Constraints

- Full-tank segment math must stay identical to existing `FuelStats.segments` (partials included; `skipped` breaks chain).
- Card shows MPG + cost/distance only — not L/100km.
- Hide economy metrics when no segment (no `—` placeholders).
- Cost uses fill-up currency + vehicle odometer unit.
- Do not change Dashboard formulas or persist economy on `FillUp`.

## File map

| Path | Role |
|------|------|
| `Sources/FuelTrack/Services/FuelStats.swift` | Add snapshot `id`; shared segment entries; `segmentsByEndingFillUpID` |
| `Scripts/fuelstats-smoke.swift` | Mirror + assert ID-keyed map and hide cases |
| `Sources/FuelTrack/Views/FillUps/FillUpListView.swift` | Compute map; pass segment into card; second metric row |

---

### Task 1: FuelStats ID-keyed segments + smoke tests

**Files:**
- Modify: `Sources/FuelTrack/Services/FuelStats.swift`
- Modify: `Scripts/fuelstats-smoke.swift`

**Interfaces:**
- Consumes: existing `ConsumptionSegment`, full-tank segment rules
- Produces:
  - `FillUpSnapshot.id: UUID`
  - `FuelStats.segmentsByEndingFillUpID(from:) -> [UUID: ConsumptionSegment]`
  - `FuelStats.segments(from:)` still returns `[ConsumptionSegment]` in odometer order (same values as today)

- [ ] **Step 1: Extend the smoke script with failing assertions for ID-keyed lookup**

Replace `Scripts/fuelstats-smoke.swift` with this full contents (includes mirrored helpers + new tests):

```swift
#!/usr/bin/env swift
import Foundation

// Standalone smoke test for FuelStats (copied formulas).
// Run: swift Scripts/fuelstats-smoke.swift

enum OdometerUnit {
    case miles, kilometers
    func toKilometers(_ value: Double) -> Double {
        switch self {
        case .miles: value * 1.609344
        case .kilometers: value
        }
    }
}

struct FillUpSnapshot {
    var id: UUID
    var date: Date
    var odometer: Double
    var liters: Double
    var totalCost: Double
    var isFullTank: Bool
    var skipped: Bool
}

struct ConsumptionSegment {
    var startOdometer: Double
    var endOdometer: Double
    var liters: Double
    var cost: Double
    var distance: Double { max(0, endOdometer - startOdometer) }
    func litersPer100km(unit: OdometerUnit) -> Double? {
        let km = unit.toKilometers(distance)
        guard km > 0, liters > 0 else { return nil }
        return liters / km * 100
    }
    func mpg(unit: OdometerUnit) -> Double? {
        guard let l100 = litersPer100km(unit: unit), l100 > 0 else { return nil }
        return 282.481 / l100
    }
    func costPerDistance(unit: OdometerUnit) -> Double? {
        guard distance > 0 else { return nil }
        return cost / distance
    }
}

func segmentEntries(from fillUps: [FillUpSnapshot]) -> [(id: UUID, segment: ConsumptionSegment)] {
    let ordered = fillUps.sorted {
        if $0.odometer != $1.odometer { return $0.odometer < $1.odometer }
        return $0.date < $1.date
    }
    var result: [(id: UUID, segment: ConsumptionSegment)] = []
    var startIndex: Int?
    for (index, fill) in ordered.enumerated() {
        if fill.skipped { startIndex = nil; continue }
        guard fill.isFullTank else { continue }
        if let start = startIndex {
            let slice = ordered[(start + 1)...index]
            let liters = slice.reduce(0) { $0 + $1.liters }
            let cost = slice.reduce(0) { $0 + $1.totalCost }
            let startOdo = ordered[start].odometer
            let endOdo = fill.odometer
            if endOdo > startOdo, liters > 0 {
                result.append((
                    id: fill.id,
                    segment: .init(startOdometer: startOdo, endOdometer: endOdo, liters: liters, cost: cost)
                ))
            }
        }
        startIndex = index
    }
    return result
}

func segments(from fillUps: [FillUpSnapshot]) -> [ConsumptionSegment] {
    segmentEntries(from: fillUps).map(\.segment)
}

func segmentsByEndingFillUpID(from fillUps: [FillUpSnapshot]) -> [UUID: ConsumptionSegment] {
    Dictionary(uniqueKeysWithValues: segmentEntries(from: fillUps).map { ($0.id, $0.segment) })
}

let day: TimeInterval = 86_400
let id1 = UUID()
let id2 = UUID()
let id3 = UUID()
let fills = [
    FillUpSnapshot(id: id1, date: .now, odometer: 1000, liters: 40, totalCost: 60, isFullTank: true, skipped: false),
    FillUpSnapshot(id: id2, date: .now.addingTimeInterval(day), odometer: 1150, liters: 20, totalCost: 30, isFullTank: false, skipped: false),
    FillUpSnapshot(id: id3, date: .now.addingTimeInterval(2 * day), odometer: 1300, liters: 25, totalCost: 40, isFullTank: true, skipped: false),
]
let segs = segments(from: fills)
assert(segs.count == 1)
assert(abs(segs[0].distance - 300) < 0.001)
assert(abs(segs[0].liters - 45) < 0.001) // 20 + 25
let l100 = segs[0].litersPer100km(unit: .miles)!
let expected = 45 / (300 * 1.609344) * 100
assert(abs(l100 - expected) < 0.01)

let byID = segmentsByEndingFillUpID(from: fills)
assert(byID[id1] == nil, "first full has no prior segment")
assert(byID[id2] == nil, "partial has no segment")
assert(byID[id3] != nil)
assert(abs(byID[id3]!.distance - 300) < 0.001)
assert(abs(byID[id3]!.liters - 45) < 0.001)
assert(abs(byID[id3]!.cost - 70) < 0.001) // 30 + 40
let mpg = byID[id3]!.mpg(unit: .miles)!
assert(abs(mpg - (282.481 / expected)) < 0.01)
let cpd = byID[id3]!.costPerDistance(unit: .miles)!
assert(abs(cpd - (70.0 / 300.0)) < 0.0001)

let idSkip = UUID()
let idAfter = UUID()
let skippedChain = [
    FillUpSnapshot(id: id1, date: .now, odometer: 1000, liters: 40, totalCost: 60, isFullTank: true, skipped: false),
    FillUpSnapshot(id: idSkip, date: .now.addingTimeInterval(day), odometer: 1200, liters: 30, totalCost: 45, isFullTank: true, skipped: true),
    FillUpSnapshot(id: idAfter, date: .now.addingTimeInterval(2 * day), odometer: 1400, liters: 30, totalCost: 45, isFullTank: true, skipped: false),
]
let skipMap = segmentsByEndingFillUpID(from: skippedChain)
assert(skipMap.isEmpty, "skipped breaks chain; no full→full pair")

print("fuelstats-smoke: PASS (L/100km=\(String(format: "%.2f", l100)), MPG=\(String(format: "%.1f", mpg)))")
```

- [ ] **Step 2: Run smoke to verify new assertions fail against the old mirror (or fail to compile)**

Run: `swift Scripts/fuelstats-smoke.swift`

Expected: either compile failure (old mirror lacks `id` / `segmentsByEndingFillUpID`) if you only partially updated, or — after Step 1’s full replace — **PASS** for the script mirror itself. The app source is still outdated until Step 3; the smoke script is self-contained. Treat Step 2 as confirming the **script** runs green with the new contract.

If Step 1 wrote the full mirrored implementation into the script, Step 2 expected output:

```
fuelstats-smoke: PASS (L/100km=..., MPG=...)
```

- [ ] **Step 3: Implement the same contract in `FuelStats.swift`**

Update `FillUpSnapshot`:

```swift
struct FillUpSnapshot: Sendable, Equatable {
    var id: UUID
    var date: Date
    var odometer: Double
    var liters: Double
    var totalCost: Double
    var isFullTank: Bool
    var skipped: Bool
}
```

Replace `segments(from:)` with shared entries + public helpers:

```swift
enum FuelStats {
    /// Full-tank method: each segment runs from one full tank to the next full tank.
    /// Liters and cost include every fill-up after the start full (partials + ending full).
    /// A fill-up marked `skipped` breaks the chain (missed fill-up).
    static func segments(from fillUps: [FillUpSnapshot]) -> [ConsumptionSegment] {
        segmentEntries(from: fillUps).map(\.segment)
    }

    /// Segments keyed by the ending full-tank fill-up id.
    static func segmentsByEndingFillUpID(from fillUps: [FillUpSnapshot]) -> [UUID: ConsumptionSegment] {
        Dictionary(uniqueKeysWithValues: segmentEntries(from: fillUps).map { ($0.id, $0.segment) })
    }

    private static func segmentEntries(from fillUps: [FillUpSnapshot]) -> [(id: UUID, segment: ConsumptionSegment)] {
        let ordered = fillUps.sorted {
            if $0.odometer != $1.odometer {
                return $0.odometer < $1.odometer
            }
            return $0.date < $1.date
        }

        var result: [(id: UUID, segment: ConsumptionSegment)] = []
        var startIndex: Int?

        for (index, fill) in ordered.enumerated() {
            if fill.skipped {
                startIndex = nil
                continue
            }

            guard fill.isFullTank else { continue }

            if let start = startIndex {
                let slice = ordered[(start + 1)...index]
                let liters = slice.reduce(0) { $0 + $1.liters }
                let cost = slice.reduce(0) { $0 + $1.totalCost }
                let startOdo = ordered[start].odometer
                let endOdo = fill.odometer
                if endOdo > startOdo, liters > 0 {
                    result.append(
                        (
                            id: fill.id,
                            segment: ConsumptionSegment(
                                startOdometer: startOdo,
                                endOdometer: endOdo,
                                liters: liters,
                                cost: cost
                            )
                        )
                    )
                }
            }

            startIndex = index
        }

        return result
    }

    // compute(...) unchanged except snapshot mapping below
```

Update `compute(vehicle:)` snapshot mapping:

```swift
static func compute(vehicle: Vehicle, calendar: Calendar = .current, now: Date = .now) -> VehicleFuelStats {
    let snapshots = vehicle.fillUps.map {
        FillUpSnapshot(
            id: $0.id,
            date: $0.date,
            odometer: $0.odometer,
            liters: $0.liters,
            totalCost: $0.totalCost,
            isFullTank: $0.isFullTank,
            skipped: $0.skipped
        )
    }
    return compute(fillUps: snapshots, unit: vehicle.odometerUnit, calendar: calendar, now: now)
}
```

Leave `compute(fillUps:unit:calendar:now:)` body unchanged (it already calls `segments(from:)`).

- [ ] **Step 4: Re-run smoke and build-check call sites**

Run:

```bash
swift Scripts/fuelstats-smoke.swift
```

Expected: `fuelstats-smoke: PASS ...`

Search for any other `FillUpSnapshot(` call sites and ensure they pass `id:` (only `FuelStats.compute(vehicle:)` and the smoke script should construct snapshots).

- [ ] **Step 5: Commit**

```bash
git add Sources/FuelTrack/Services/FuelStats.swift Scripts/fuelstats-smoke.swift
git commit -m "$(cat <<'EOF'
feat: key full-tank segments by ending fill-up id

EOF
)"
```

---

### Task 2: Fuel Log card UI

**Files:**
- Modify: `Sources/FuelTrack/Views/FillUps/FillUpListView.swift`

**Interfaces:**
- Consumes: `FuelStats.segmentsByEndingFillUpID(from:) -> [UUID: ConsumptionSegment]`, `Formatters.consumptionMPG`, `Formatters.costPerDistance`
- Produces: `FillUpCard` shows optional second metric row (MPG + per-distance cost)

- [ ] **Step 1: Build the segment map in `FillUpListView`**

Inside the `else if let vehicle = activeVehicle` branch (where the list is built), before the `LazyVStack`, compute:

```swift
let economyByFillID: [UUID: ConsumptionSegment] = {
    let snapshots = fillUps.map {
        FillUpSnapshot(
            id: $0.id,
            date: $0.date,
            odometer: $0.odometer,
            liters: $0.liters,
            totalCost: $0.totalCost,
            isFullTank: $0.isFullTank,
            skipped: $0.skipped
        )
    }
    return FuelStats.segmentsByEndingFillUpID(from: snapshots)
}()
```

Note: `fillUps` is newest-first (`sortedFillUps.reversed()`); the FuelStats helpers re-sort by odometer, so order here does not matter.

- [ ] **Step 2: Pass the optional segment into `FillUpCard`**

Update the `ForEach` label:

```swift
FillUpCard(
    fillUp: fillUp,
    unit: vehicle.odometerUnit,
    segment: economyByFillID[fillUp.id]
)
```

- [ ] **Step 3: Update `FillUpCard` to show the economy row when present**

Change the private struct to:

```swift
private struct FillUpCard: View {
    let fillUp: FillUp
    let unit: OdometerUnit
    let segment: ConsumptionSegment?

    var body: some View {
        InstrumentListRow(tint: GlassTheme.accentWarm) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Formatters.shortDate(fillUp.date))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if !fillUp.station.isEmpty {
                            Text(fillUp.station)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } else {
                            Text(fillUp.fuelType.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(Formatters.currency(fillUp.totalCost, code: fillUp.currencyCode))
                        .font(FuelTrackTokens.numericFont(size: .title3))
                        .foregroundStyle(GlassTheme.accentWarm)
                }

                HStack(spacing: 16) {
                    metric(Formatters.liters(fillUp.liters), label: "Volume", tint: GlassTheme.accent)
                    metric(Formatters.odometer(fillUp.odometer, unit: unit), label: "Odo", tint: GlassTheme.accent)
                    if let ppl = fillUp.pricePerLiter {
                        metric(Formatters.pricePerLiter(ppl, code: fillUp.currencyCode), label: "Per litre", tint: GlassTheme.accentWarm)
                    }
                }

                if let segment {
                    HStack(spacing: 16) {
                        metric(
                            Formatters.consumptionMPG(segment.mpg(unit: unit)),
                            label: "MPG",
                            tint: GlassTheme.accentWarm
                        )
                        metric(
                            Formatters.costPerDistance(
                                segment.costPerDistance(unit: unit),
                                unit: unit,
                                code: fillUp.currencyCode
                            ),
                            label: unit == .miles ? "Per mi" : "Per km",
                            tint: GlassTheme.accentWarm
                        )
                    }
                }

                HStack(spacing: 8) {
                    Text(fillUp.fuelType.shortName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(GlassTheme.accent))
                    Text(fillUp.isFullTank ? "Full tank" : "Partial")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(fillUp.isFullTank ? GlassTheme.success : GlassTheme.warning)
                    if fillUp.skipped {
                        Text("Missed prior")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(GlassTheme.error)
                    }
                    Spacer()
                }
            }
        }
    }

    private func metric(_ value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(FuelTrackTokens.labelFont())
                .tracking(0.05)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(FuelTrackTokens.numericFont(size: .subheadline))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 4: Manual verify**

In the simulator / device:

1. Vehicle with two full tanks and a partial between → ending full card shows MPG + Per mi/km; first full and partial do **not**.
2. Mark a fill `skipped` (Missed prior) → no economy until a new full→full pair exists.
3. Confirm values match Dashboard “Last tank MPG” / cost math for the latest segment.

- [ ] **Step 5: Commit**

```bash
git add Sources/FuelTrack/Views/FillUps/FillUpListView.swift
git commit -m "$(cat <<'EOF'
feat: show tank MPG and cost/distance on fuel log cards

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Full-tank method / same as Dashboard | Task 1 |
| `FillUpSnapshot.id` + `segmentsByEndingFillUpID` | Task 1 |
| MPG + cost/distance on card | Task 2 |
| Hide when no segment | Task 2 (`if let segment`) |
| Fill-up currency + vehicle unit | Task 2 |
| Smoke tests for map + hide cases | Task 1 |
| No Dashboard / persistence changes | (intentionally omitted) |
