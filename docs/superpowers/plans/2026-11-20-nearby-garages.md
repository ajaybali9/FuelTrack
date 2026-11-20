# Nearby Garages Implementation Plan

> **For agentic workers:** Execute task-by-task. Spec is locked in `docs/superpowers/specs/2026-11-20-nearby-garages-design.md`.

**Goal:** Nearby MOT + repair garages with authentic UK DVSA data and MapKit for repair/Europe; More entry + Home shortcut; no prices.

**Architecture:** Separate `NearbyGaragesService` from fuel `NearbyStationsService`. Bundle geocoded DVSA Class 4+ stations; MapKit for repair. Reuse `LocationProvider`.

**Tech Stack:** SwiftUI, CoreLocation, MapKit, bundled JSON resource, existing GlassTheme / Instrument chrome.

## File map

| Path | Role |
|------|------|
| `Scripts/build-uk-mot-stations.py` | Download DVSA CSV, geocode via postcodes.io, emit JSON |
| `Sources/FuelTrack/Resources/uk-mot-stations.json` | Bundled geocoded MOT asset |
| `Sources/FuelTrack/Resources/uk-mot-stations.meta.json` | Register date + OGL note |
| `Package.swift` | Register Resources |
| `Sources/FuelTrack/Models/NearbyGarage.swift` | Runtime POI model + kinds/source |
| `Sources/FuelTrack/Services/GarageRegion.swift` | UK / Europe / elsewhere gate |
| `Sources/FuelTrack/Services/UKMOTStationsStore.swift` | Load asset + Haversine nearby |
| `Sources/FuelTrack/Services/NearbyGaragesService.swift` | Orchestrate DVSA + MapKit |
| `Sources/FuelTrack/Views/Garages/NearbyGaragesView.swift` | Full list/map UI |
| `Sources/FuelTrack/Views/Garages/HomeGarageQuickAccess.swift` | Home shortcut card |
| `Sources/FuelTrack/Views/Dashboard/DashboardView.swift` | Embed home card |
| `Sources/FuelTrack/Views/More/MoreView.swift` | Navigation entry |
| `Support/Info.plist` | Location purpose mentions garages |
| `Scripts/mot-nearby-smoke.swift` | Pure Haversine / filter smoke |

## Tasks

### Task 1: DVSA asset pipeline
- [ ] Script downloads CSV, bulk-geocodes postcodes, writes Class 4+ JSON + meta
- [ ] Register resources in `Package.swift`

### Task 2: Models + stores + service
- [ ] `NearbyGarage`, `GarageRegion`, `UKMOTStationsStore`, `NearbyGaragesService`
- [ ] MOT = DVSA nearby; Repair = MapKit `automotiveRepair` / NL query
- [ ] Region gate: UK/Europe only

### Task 3: UI
- [ ] `NearbyGaragesView` (filters, radius, list/map, detail)
- [ ] More → Nearby garages
- [ ] `HomeGarageQuickAccess` + Dashboard section
- [ ] Attribution badges (DVSA vs Apple Maps)

### Task 4: Polish + verify
- [ ] Info.plist location strings
- [ ] `Scripts/mot-nearby-smoke.swift`
- [ ] Commit / push / update PR

## Constraints

- Do not change Stations / fuel-price behaviour
- No prices UI
- Do not claim MapKit rows are DVSA-authorised
- Keep asset Class 4+ (cars) for size; include `classes` array for display
