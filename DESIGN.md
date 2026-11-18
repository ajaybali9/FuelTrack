---
# gstack: design-md-format=spec
name: FuelTrack
description: Fuel Computer — industrial-precision instrument UI; glass panels, tabular numerals, dual-signal teal and sodium.
colors:
  primary: "#388EAB"
  on-primary: "#FCFCFB"
  surface: "#EEF5F8"
  text: "#142338"
  text-muted: "#5C6670"
  accent: "#388EAB"
  accent-warm: "#EB8538"
  deep: "#0D1A2E"
  ink: "#142338"
  success: "#2F7A4A"
  warning: "#C47A1A"
  error: "#B83A2E"
typography:
  display:
    fontFamily: Epilogue
    fontWeight: 700
    fontSize: 1.75rem
    letterSpacing: -0.03em
  body:
    fontFamily: Epilogue
    fontSize: 1rem
    lineHeight: 1.45
  label:
    fontFamily: Epilogue
    fontSize: 0.6875rem
    letterSpacing: 0.06em
  mono:
    fontFamily: "IBM Plex Mono"
    fontFeature: tnum
rounded:
  sm: 8px
  md: 14px
  lg: 20px
  xl: 24px
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  2xl: 32px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
  input:
    borderColor: "{colors.text-muted}"
    rounded: "{rounded.md}"
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.xl}"
---

# FuelTrack — Fuel Computer

## Overview

**Creative North Star:** Instrument-grade trip computer — numbers first, glass panels, dual-signal color (teal for distance/economy, warm sodium for money).
**Product context:** Personal on-device fuel and vehicle tracker (UK/India), SwiftUI Operate surfaces.
**Mode per surface:** Operate (forms, dashboard, settings); Persuade (landing only).
**Key characteristics:**
- Large tabular numerals with unit suffixes
- Glass sections instead of stock `Form` chrome
- Micro-labels in tracked uppercase
- Live derived metrics (Price/L, economy hints)
- Light and dark both first-class

## Colors

**Strategy:** Committed dual-signal — teal owns distance/economy; warm sodium owns cost; neutrals derive from deep ink.
**Light or dark:** User preference (system / light / dark). Dark uses deep navy gradients already in `AppBackdrop`.

Semantic mapping:
- Teal (`accent`) — odometer, distance, economy, primary actions
- Warm (`accent-warm`) — money, cost chips, price accents
- Success / warning / error — compliance and validation

## Typography

- **Display / body / label:** Epilogue (bundled or system fallback to SF Pro with same scale)
- **Numeric / mono:** IBM Plex Mono with `tnum`, fallback SF Mono
- Labels: caption2, semibold, tracked, uppercase for instrument rows
- Values: title3–title2 weight semibold for primary numerics

## Layout

- Forms: `ScrollView` + glass section cards (`GlassFormScaffold`), 16pt horizontal padding, 12pt section gap
- Primary numeric fields stacked with generous hit targets (min 52pt)
- Progressive disclosure for notes / optional compliance dates
- Sticky live metrics strip above keyboard / safe area bottom on fill-up

## Elevation & Depth

- Prefer iOS `glassEffect` on cards and chips
- Soft offset shadows only when glass unavailable
- No zero-offset neon glow

## Shapes

- Cards 20–24pt continuous corner
- Chips 14pt
- Plate field slightly more rectangular (12pt) to evoke UK plate

## Components

Shared kit under `Sources/FuelTrack/Theme/Fields/`:
- `GlassFormScaffold`, `FTNumericField`, `FTChipPicker`, `FTStationField`, `FTDateField`, `FTToggleRow`, `FTTextArea`, `FTSecureField`, `FTLiveMetricsStrip`, `FTPlateField`, `FTComplianceRail`

States required: empty, focused, invalid, disabled — light and dark.

## Do's and Don'ts

- Do: use tabular mono for every editable number
- Do: gate motion with Reduce Motion
- Do: keep DVLA / station / save behavior identical while reskinning
- Don't: leave stock `Form` on primary entry screens
- Don't: purple gradients, glow edges, or nested cards
- Don't: invent cloud sync or social proof

## Motion

- **Approach:** intentional
- **Easing:** enter ease-out, exit ease-out, move ease-in-out
- **Duration:** micro 80ms, short 220ms, medium 320ms
- **Authored moments:** section stagger; live metrics morph; DVLA success pulse

## Landing token map

| DESIGN.md / Swift | landing/tokens.css |
|-------------------|--------------------|
| colors.accent `#388EAB` | `--color-accent` |
| colors.accent-warm `#EB8538` | `--color-accent-warm` |
| colors.success / warning / error | `--color-success` / `--color-warning` / `--color-error` |
| typography.display/body Epilogue | `--font-display` / `--font-body` |
| typography.mono IBM Plex Mono | `--font-outlier` |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-11-18 | Fuel Computer field system | Elevate glass home aesthetic into all entry fields; trust numbers |
| 2026-11-18 | Replace Form with glass scroll | Kill dual UI language |
| 2026-11-18 | Dual-signal teal / sodium | Distance vs money at a glance |
