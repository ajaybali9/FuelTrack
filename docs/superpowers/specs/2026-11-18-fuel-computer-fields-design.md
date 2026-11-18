# Fuel Computer Fields Design

**Date:** 2026-11-18  
**Status:** Approved for implementation  
**App:** FuelTrack (SwiftUI + SwiftData, iPhone)

## Goal

Replace stock SwiftUI `Form` entry chrome with a shared instrument-grade glass field kit (“Fuel Computer”) so every input surface matches the glass dashboard language, with advanced live metrics and consistent dual-signal color.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Aesthetic | Fuel Computer / industrial instrument |
| Form container | `ScrollView` + glass sections (`GlassFormScaffold`), not stock `Form` |
| Typography | Epilogue-like UI + IBM Plex Mono / SF Mono tabular for numerics |
| Color | Teal = distance/economy; warm sodium = money; semantic success/warning/error |
| Scope | All form/input surfaces; dashboard only if shared tokens require touch |
| Landing | Token name sync only; no landing rebuild |
| Behavior | Preserve SwiftData, FuelStats, DVLA, station, backup contracts |

## Non-goals

- Cloud sync / accounts
- Redesigning trip GPS engine or map clustering
- Changing economy math
- Marketing site rewrite

## Component contracts

### GlassFormScaffold
- Inputs: title, optional toolbar, `@ViewBuilder` sections
- Each section: optional title + glass card content
- Applies `.fuelTrackForm()`, keyboard-safe padding, optional stagger

### FTNumericField
- Bindings: `text: Binding<String>`, label, unit suffix, keyboard
- States: focused ring (accent), invalid (error + shake/haptic once), disabled
- Font: mono tabular

### FTChipPicker\<T: Hashable & Identifiable\>
- Horizontal chips for enum selections (currency, fuel, appearance, DVLA env)

### FTStationField
- Text + map pin button + optional price badge + fill-from-price action

### FTDateField / optional date rail
- Compact date row; optional dates via enable toggle + picker

### FTToggleRow
- Label + optional caption + Toggle

### FTTextArea / FTSecureField
- Notes area; masked API key with optional status pill

### FTLiveMetricsStrip
- Sticky strip: Price/L; optional economy hint string

### FTPlateField
- Single registration source; plate-like tracking / width

### FTComplianceRail
- MOT / tax / insurance status chips + DVLA refresh button (progress)

## Migration waves

1. Fill-up + Station picker  
2. Vehicle + Compliance  
3. Spend / personal / categories / budgets  
4. Settings / reminders / backup  

## Testing

Per-wave QA checklists + smoke scripts; final a11y (Dynamic Type, VoiceOver, Reduce Motion).

## Success criteria

- Primary entry screens no longer use stock `Form` sections (or documented exception)
- Numeric fields use tabular figures
- Fill-up live Price/L updates
- Smokes green; DVLA/station/trip behavior unchanged
