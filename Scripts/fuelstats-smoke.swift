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
}

func segments(from fillUps: [FillUpSnapshot]) -> [ConsumptionSegment] {
    let ordered = fillUps.sorted {
        if $0.odometer != $1.odometer { return $0.odometer < $1.odometer }
        return $0.date < $1.date
    }
    var result: [ConsumptionSegment] = []
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
                result.append(.init(startOdometer: startOdo, endOdometer: endOdo, liters: liters, cost: cost))
            }
        }
        startIndex = index
    }
    return result
}

let day: TimeInterval = 86_400
let fills = [
    FillUpSnapshot(date: .now, odometer: 1000, liters: 40, totalCost: 60, isFullTank: true, skipped: false),
    FillUpSnapshot(date: .now.addingTimeInterval(day), odometer: 1150, liters: 20, totalCost: 30, isFullTank: false, skipped: false),
    FillUpSnapshot(date: .now.addingTimeInterval(2 * day), odometer: 1300, liters: 25, totalCost: 40, isFullTank: true, skipped: false),
]
let segs = segments(from: fills)
assert(segs.count == 1)
assert(abs(segs[0].distance - 300) < 0.001)
assert(abs(segs[0].liters - 45) < 0.001) // 20 + 25
let l100 = segs[0].litersPer100km(unit: .miles)!
// 45 L over 300 mi = 45 / (300*1.609344) * 100
let expected = 45 / (300 * 1.609344) * 100
assert(abs(l100 - expected) < 0.01)
print("fuelstats-smoke: PASS (L/100km=\(String(format: "%.2f", l100)))")
