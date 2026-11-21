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