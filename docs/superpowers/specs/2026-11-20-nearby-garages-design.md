# Nearby Garages Design

**Date:** 2026-11-20  
**Status:** Draft for review  
**App:** FuelTrack (SwiftUI + SwiftData, iPhone)

## Goal

Let the driver find nearby **MOT centres** and **repair / service garages** with authentic location data — no prices. UK-first; Europe supported via Apple Maps POIs. Separate entry from Stations, with a Home shortcut patterned on Fuel nearby.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Scope | Both MOT centres and general repair / service |
| Geography | UK first; Europe OK based on device location; outside Europe → soft unavailable |
| Placement | Separate feature (not Stations tab) + Home shortcut like Fuel |
| Prices | Out of scope — no pump/labour pricing |
| Authenticity | UK MOT = DVSA Active MOT stations (official). Repair / Europe = MapKit automotive / inspection POIs |
| Naming | UI label **Nearby garages** (avoid clash with More → section titled “Garage” for vehicles) |

## Why not the fuel API

`NearbyStationsService` → `cheapestfuelnearme.co.uk` is UK **Fuel Finder** pump prices only. It does not list repair shops or MOT centres. Garages need a different pipeline.

## Data sources

### UK MOT (authoritative)

- **Source:** DVSA [Active MOT test stations](https://www.gov.uk/government/publications/active-mot-test-stations) CSV (Open Government Licence).
- **Fields used:** site number, trading name, address, town, postcode, phone, Class 1–7 flags.
- **Default filter for cars:** Class 4.
- **Gap:** CSV has **no coordinates**. Offline build step geocodes postcodes (e.g. [postcodes.io](https://api.postcodes.io/)) and ships a compact on-device asset.
- **Freshness:** DVSA updates ~quarterly → regenerate asset + ship in app update (or optional future refresh download). No invented cloud sync account.

### Repair / service + Europe

- **Source:** Apple MapKit (`MKLocalSearch` / points-of-interest).
- Prefer `MKPointOfInterestCategory.automotiveRepair` where available (iOS 18+); natural-language queries (“car repair”, “garage”, “MOT”) as needed.
- Works in UK and wider Europe without API keys; fits privacy-first on-device product.
- Not a government register — shown as **Map** / Apple Places results, never labelled as DVSA-authorised unless matched.

### Explicitly out of v1

- Google Places / paid third-party MOT APIs
- OpenStreetMap Overpass as primary (optional later fallback only)
- Labour / parts pricing
- India / rest-of-world nearby search (show clear “UK & Europe for now” empty state)

## Feature tree

```
Nearby Garages
├── Permissions
│   └── Reuse LocationProvider (When-In-Use) — same as Stations
├── Region gate
│   ├── UK / Europe → search enabled
│   └── Else → ContentUnavailable + short explanation
├── Data
│   ├── NearbyGarage model (in-memory; not SwiftData v1)
│   ├── UKMOTStationsStore (bundled geocoded DVSA asset)
│   └── NearbyGaragesService (orchestrates MOT + MapKit)
├── Filters
│   ├── All
│   ├── MOT (UK: DVSA Class 4+; Europe: MapKit inspection/repair heuristics)
│   └── Repair (MapKit automotiveRepair)
├── Home UX
│   ├── Section “Nearby garages”
│   └── HomeGarageQuickAccess (nearest chips → open full list)
├── Full UX
│   ├── More → Nearby garages (primary entry)
│   ├── List + map (distance sort; no price chrome)
│   └── Detail: address, phone, distance, MOT classes (if DVSA), Maps / Call
└── Attribution
    ├── DVSA / OGL for MOT rows
    └── Apple Maps for MapKit rows
```

## Architecture

```
LocationProvider (existing, unchanged role)
        │
        ├─ NearbyStationsService     → fuel prices (Stations tab / Home fuel)
        └─ NearbyGaragesService      → new
                 ├─ UKMOTStationsStore   → bundled DVSA geocoded points + Haversine
                 └─ MapKitLocalSearch    → repair (+ Europe MOT-ish POIs)
```

- Keep fuel and garage pipelines separate.
- No changes to Fuel Finder contract.
- v1 does **not** persist garage favourites in SwiftData (can revisit later via `SavedStation`-like model).

### Region detection

- Derive country/region from reverse-geocode of current coordinate (or coarse lat/lon bounds as fallback).
- **UK:** England / Scotland / Wales / NI — DVSA asset covers GB; NI may be sparse/empty in DVSA file → fall back to MapKit for MOT filter when asset has no hits.
- **Europe:** MapKit only for both filters.
- **Elsewhere:** feature disabled with copy, not a hard crash.

## Data model (runtime)

### `NearbyGarage`

| Field | Notes |
|-------|--------|
| `id` | DVSA site number or MapKit stable id / coordinate hash |
| `name` | Trading name / placemark name |
| `address` / `town` / `postcode` | As available |
| `coordinate` | Required for map + distance |
| `phone` | Optional |
| `distanceMiles` | From `LocationProvider` |
| `kinds` | `.mot`, `.repair` (set can contain both) |
| `motClasses` | `[Int]?` — DVSA only |
| `source` | `.dvsa` / `.mapKit` |
| `mapsURL` | Apple Maps directions |

## UI placement

| Surface | Behaviour |
|---------|-----------|
| **Home** | New section + `HomeGarageQuickAccess` under (or beside) Nearby fuel — nearest MOT / repair chips, refresh, tap → full screen |
| **More** | Row under existing Garage group: **Nearby garages** → list/map |
| **Stations tab** | Unchanged (fuel prices only) |

### Full screen (`NearbyGaragesView`)

- Chip filter: All · MOT · Repair
- Radius: reuse 5 / 10 / 20 mi pattern from Stations
- List default; map toggle
- Sort by distance only
- Detail sheet: call, directions, MOT classes + “Official DVSA register” badge when `source == .dvsa`
- Empty / error / location-denied states mirror Stations tone

### Home card (`HomeGarageQuickAccess`)

- Headline: Nearby garages
- Show up to ~5 nearest (All filter, default 10 mi)
- Chip content: name + distance (+ small MOT badge if DVSA)
- No price UI
- Link / navigation into `NearbyGaragesView`

## Offline build (UK MOT asset)

Script under `Scripts/` (run on a Mac/dev machine when refreshing data):

1. Download DVSA active MOT CSV.
2. Bulk-geocode unique postcodes via postcodes.io (respect rate limits).
3. Emit `Resources/uk-mot-stations.json` (or similar): `{ id, name, address, town, postcode, phone, lat, lon, classes: [4,…] }`.
4. Document licence + last DVSA publish date in script header / Resources sidecar.

App loads asset once into memory (or memory-map); nearby query = Haversine + Class 4 filter + radius + limit.

## Attribution / trust copy

- DVSA rows: “MOT centre · DVSA register” + OGL acknowledgement in Settings or detail footer.
- MapKit rows: “From Apple Maps” — never claim official MOT authorisation unless DVSA-matched.
- Optional later: fuzzy match MapKit ↔ DVSA by postcode + name for a dual badge; **not required for v1**.

## Non-goals (v1)

- Prices, reviews, booking, opening-hours guarantees
- Cloud sync / account
- Changing Stations tab into a multi-POI hub
- Bundling full raw DVSA CSV without geocoding
- India / worldwide coverage

## Risks

| Risk | Mitigation |
|------|------------|
| DVSA CSV has no lat/lon | Offline geocode → bundled asset |
| Asset size (~20k sites) | Compact JSON; filter Class 4; consider gzip / binary later if needed |
| Quarterly staleness | Show “Register as of \<date\>” in UI |
| Name clash with More “Garage” | Feature title **Nearby garages** |
| MapKit ≠ official MOT | Clear source badges; MOT filter prefers DVSA in UK |
| Europe fragmented official registers | MapKit only; honest copy |

## Acceptance (v1)

1. From Home, user sees Nearby garages shortcut and can open the full list.
2. From More → Nearby garages, list + map show results when location is UK/Europe.
3. MOT filter in GB surfaces DVSA Class 4 centres with phone/address/distance.
4. Repair filter surfaces MapKit automotive repair results (no prices).
5. Outside Europe, feature explains UK/Europe focus instead of empty spinner forever.
6. Stations / fuel price behaviour unchanged.
7. Location permission copy updated if needed to mention finding nearby garages as well as petrol stations.

## Open points (do not block v1)

- Fuzzy DVSA ↔ MapKit merge for dual-source rows
- Persist favourite garages
- Deep link from MOT reminder due card → nearby MOT list
- Optional Overpass fallback if MapKit is thin in a locale

## Implementation order (after approval)

1. Spec approved → write implementation plan under `docs/superpowers/plans/`.
2. Offline DVSA geocode script + ship asset.
3. `NearbyGarage` + `UKMOTStationsStore` + `NearbyGaragesService`.
4. `NearbyGaragesView` + More entry.
5. `HomeGarageQuickAccess` + Dashboard section.
6. Region gate, attribution, Info.plist location purpose string refresh.
7. Smoke / manual verify on device (UK location or simulated).
