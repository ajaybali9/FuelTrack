# Fill-up Card Economy Design

**Date:** 2026-11-21  
**Status:** Approved  
**App:** FuelTrack (SwiftUI + SwiftData, iPhone)

## Goal

On the Fuel Log screen, each fill-up that closes a full-tank consumption segment shows the **average mileage (UK MPG)** and **cost per distance** for that tank. Values come from previous full-tank odo → current full-tank odo using the same rules as Dashboard.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Calculation | Full-tank method (same as `FuelStats.segments`) |
| Display | MPG only + cost per distance (not L/100km on the card) |
| Ineligible fills | Hide metrics entirely (no `—` placeholders) |
| Architecture | Extend `FuelStats` with per-fill segment lookup keyed by ending fill-up ID |
| Currency / unit | Fill-up currency + vehicle odometer unit (not hard-coded £/mi) |
| Scope | Fuel Log list cards only — no Dashboard formula changes, no persisted MPG field |

## Calculation

Reuse existing full-tank rules in `FuelStats`:

1. Order fill-ups by odometer, then date.
2. A **segment** runs from one full tank to the next full tank.
3. Liters and cost include every fill after the start full (partials + ending full).
4. A fill marked `skipped` breaks the chain.
5. Invalid segments (non-increasing odo, zero liters) are omitted — same as today.

Economy for a segment:

- **Distance** = `endOdometer − startOdometer` (in vehicle odometer unit)
- **MPG** = UK imperial from L/100km via existing `ConsumptionSegment.mpg(unit:)`
- **Cost / distance** = `cost / distance` via existing `ConsumptionSegment.costPerDistance(unit:)`

## Data API

1. Add `id: UUID` to `FillUpSnapshot`.
2. Thread `FillUp.id` through `FuelStats.compute(vehicle:)` snapshot mapping.
3. Add `FuelStats.segmentsByEndingFillUpID(from:) -> [UUID: ConsumptionSegment]` built from the same segment walk, keyed by the **ending** full-tank fill-up’s id.
4. Existing `segments(from:)` / `compute(...)` behaviour stays unchanged aside from carrying `id` on snapshots (id ignored by current aggregations).

## UI

**Where:** `FillUpListView` → `FillUpCard`

**Wiring:**

- List computes the segment map once for the active vehicle’s fill-ups.
- Passes the optional `ConsumptionSegment` (or derived MPG + cost/distance) into each card for that fill-up’s id.

**Card layout:**

- Existing first metric row unchanged: Volume, Odo, Per litre.
- When a segment exists for that fill-up, show a **second** metric row:
  - **MPG** — `Formatters.consumptionMPG(...)`
  - **Per mi** / **Per km** — `Formatters.costPerDistance(..., unit:, code:)` (label/unit follow vehicle odometer unit; currency from the fill-up)
- When no segment: omit the second row entirely.

**Unchanged:** fuel type / Full tank / Partial / Missed prior badges; navigation to edit form; summary chips at top of the screen.

## Edge cases

| Case | Behaviour |
|------|-----------|
| First full tank (no prior full) | No economy row |
| Partial fill | No economy row; liters still included in next full’s segment |
| After `skipped` until next full→full pair | No economy row |
| Odo not increasing / zero liters | No segment → no economy row |
| Miles vs km vehicle | Cost formatter uses that unit |
| Non-GBP currency | Cost formatter uses fill-up currency |

## Testing

Extend `Scripts/fuelstats-smoke.swift` (mirror of `FuelStats` formulas) to assert:

1. Ending full-tank fill ID maps to the expected segment (distance, liters, cost).
2. Partial, first full, and post-`skipped` fills have **no** map entry.
3. MPG and cost-per-distance match segment helper formulas for a known fixture.

## Out of scope

- Showing L/100km on Fuel Log cards
- Changing Dashboard “Last tank” / average economy math
- Storing economy on `FillUp` in SwiftData
- Per-fill “simple consecutive” economy (current odo − previous any fill ÷ this fill’s liters)
- Economy on the fill-up form / detail beyond the list card

## Implementation touchpoints

| File | Change |
|------|--------|
| `Sources/FuelTrack/Services/FuelStats.swift` | Snapshot `id`; `segmentsByEndingFillUpID` |
| `Sources/FuelTrack/Views/FillUps/FillUpListView.swift` | Compute map; pass into card; second metric row |
| `Scripts/fuelstats-smoke.swift` | Cover ID-keyed segments + hide cases |
