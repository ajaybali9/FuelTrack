# Fuel Computer Fields Implementation Plan

> **For agentic workers:** Execute task-by-task. Do not re-litigate aesthetic (Fuel Computer). Preserve SwiftData/DVLA/station/backup behavior.

**Goal:** Shared glass field kit + migrate all FuelTrack form surfaces.

**Architecture:** `Theme/Fields/*` components; forms become `GlassFormScaffold` scroll UIs.

**Tech Stack:** SwiftUI, iOS 26 glassEffect, existing GlassTheme.

## Global Constraints

- No model/schema/math changes
- Respect Reduce Motion
- No commits unless user asks
- DESIGN.md is source of truth for tokens

## Autoplan lean review (2026-11-18)

**Status:** APPROVED_WITH_NOTES

**P0/P1 applied:**
1. **P0 a11y:** Every custom field must set accessibilityLabel / value; toggles keep Switch trait.
2. **P0 focus:** Invalid shake must not run in a loop — fire once per validation edge.
3. **P1 Dynamic Type:** Prefer `@ScaledMetric` / text styles over fixed pt where possible; mono numerics may cap scale.
4. **P1 plate duplication:** One `FTPlateField` binding on vehicle create/edit; compliance editor must not duplicate registration TextField.

**Accepted non-issues:** Custom scroll vs Form (thesis); Epilogue may fall back to SF until font bundled; live economy hint may be omitted when insufficient full-tank history.

---

### Task A: Field kit
- Create `Sources/FuelTrack/Theme/Fields/*.swift` + extend GlassTheme tokens
- Previews for states

### Task B: Fill-up + station
### Task C: Vehicle + compliance
### Task D: Money forms
### Task E: System forms
### Task F: Landing token sync
### QA 1–4 + Final
