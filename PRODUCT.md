# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Primary user is Ajay — personal multi-vehicle driving spanning UK and India contexts. The job is to log fuel, understand true economy and cost, and keep UK vehicle compliance dates visible without depending on a cloud account or a third-party fuel app.

## Product Purpose

FuelTrack is a personal iPhone fuel and vehicle tracker. It records fill-ups, computes full-tank economy and cost stats, supports dual currencies (GBP/INR) and distance units (miles/km), and extends into trips, vehicle/personal spend, reminders, and UK compliance. Success means the owner can trust on-device history and see fuel cost, economy, and MOT/tax-related reminders in one private app.

## Positioning

Privacy-first and UK-compliance-aware: all primary data stays on device, with native backup round-trips and UK-oriented compliance (MOT/tax/DVLA-related flows) as the durable wedge versus a generic fuel log.

## Operating Context

- Native iPhone app via SwiftUI + SwiftData, deployed with xtool (`bundleID`: `com.ajaybali.FuelTrack`)
- Active-vehicle selection across multiple vehicles
- Full native backup export/import for device moves
- On-device workflows only in the current product stage (no account, no sync)

## Capabilities and Constraints

**Confirmed capabilities**

- Multi-vehicle fill-up logging (litres, full/partial, missed fill-up)
- GBP and INR; miles or kilometres per vehicle
- Dashboard stats via full-tank method (L/100km, UK MPG, cost/distance)
- Native FuelTrack backup round-trip
- Trips (GPS logger), car/personal spend, reminders, nearby stations, DVLA/compliance-related vehicle fields

**Hard constraints**

- On-device storage only for now — no account / no cloud sync
- Product name **FuelTrack**; bundle ID `com.ajaybali.FuelTrack`
- Must not invent cloud sync, multi-user accounts, or fabricated social proof

**Open / undecided**

- Whether (or when) App Store distribution beyond personal use becomes a goal
- Whether cloud sync ever becomes optional later
- Accessibility standard beyond Apple platform defaults — not yet specified

## Brand Commitments

- Product name: FuelTrack
- Custom app icon at `Resources/AppIcon.png`
- Voice: practical personal tool; no marketing persona locked yet beyond privacy and UK usefulness

## Evidence on Hand

- Running SwiftUI codebase under `Sources/FuelTrack/`
- README feature and setup docs
- Smoke scripts under `Scripts/` (fuel stats, trip stats, backup round-trip)
- Trip logger plan/spec under `docs/superpowers/`
- No testimonials, press, or third-party benchmarks — do not fabricate any

## Product Principles

1. **Private by default** — treat on-device ownership as a product promise, not an implementation detail.
2. **Trust the numbers** — economy and cost math should stay explainable (full-tank method) and consistent across backups.
3. **UK-ready personal use** — compliance dates and dual currency/distance contexts matter as much as logging a fill-up.
4. **One owner, many vehicles** — optimize for a single trusted user with multiple cars, not multi-tenant SaaS.
5. **Ship the job, not the category** — prefer features that close the personal tracking loop over generic car-app sprawl.

## Accessibility & Inclusion

No product-specific accessibility mandate beyond standard iOS expectations has been confirmed yet.
