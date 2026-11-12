# FuelTrack

Fuelio-inspired multi-vehicle fuel tracker for iPhone, built with SwiftUI + SwiftData and deployed via [xtool](https://xtool.sh).

## v1 features

- Multiple vehicles with active-vehicle selection
- Fill-up log (litres, full/partial tank, missed fill-up flag)
- GBP and INR currencies (per vehicle / per fill-up)
- Miles or kilometres per vehicle
- Dashboard stats using the full-tank method (L/100km, UK MPG, cost/distance)
- Import from Fuelio CSV (Settings → Import from Fuelio CSV)
- Custom app icon
- On-device SwiftData storage (no account / no cloud in v1)

## Project layout

```
Sources/FuelTrack/
  Models/       Vehicle, FillUp, enums
  Services/     FuelStats, Formatters
  Support/      ActiveVehicleStore
  Views/        Dashboard, Fill-ups, Vehicles, Settings
```

## Requirements

1. **Xcode** (full app, not only Command Line Tools) — provides the iOS SDK  
   Install from the Mac App Store, or with [Xcodes](https://github.com/XcodesOrg/xcodes):  
   `xcodes install 27.2 --select`
2. **xtool** — already installable with Homebrew:  
   `brew install xtool-org/tap/xtool`
3. A connected iPhone with **Developer Mode** enabled

## First-time setup

```bash
# 1. Point at Xcode after installing it
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcrun -sdk iphoneos -show-sdk-path   # should print an SDK path

# 2. Authenticate xtool (Apple ID password mode or API key)
xtool setup

# 3. Build, sign, install, and launch on the connected phone
cd /Users/ajaybali/Documents/ClaudeProjects/FuelTrack
xtool devices   # confirm your iPhone appears
xtool dev
```

Bundle ID: `com.ajaybali.FuelTrack` (see `xtool.yml`).

## Import from Fuelio

1. In Fuelio: Settings → Export CSV (one vehicle per file).
2. In FuelTrack: Settings → Import from Fuelio CSV → choose the file.
3. Pick GBP or INR for the imported costs (Fuelio CSV has no currency field).

## Verify without a device

```bash
swift Scripts/fuelstats-smoke.swift
swift Scripts/fuelio-import-smoke.swift
```

## Current machine status (as of scaffold)

- FuelTrack sources and `xtool.yml` are in place
- `xtool` CLI is installed (`/opt/homebrew/bin/xtool`)
- Phone was detected: `Ajay’s iPhone [usb]`
- `xtool dev` cannot finish until **Xcode** is installed and `xtool setup` / `xtool auth login` succeeds
