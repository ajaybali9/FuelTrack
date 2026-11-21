import Foundation

struct FillUpSnapshot: Sendable, Equatable {
    var id: UUID
    var date: Date
    var odometer: Double
    var liters: Double
    var totalCost: Double
    var isFullTank: Bool
    var skipped: Bool
}

struct ConsumptionSegment: Sendable, Equatable {
    var startOdometer: Double
    var endOdometer: Double
    var liters: Double
    var cost: Double

    var distance: Double { max(0, endOdometer - startOdometer) }

    /// Liters per 100 km, with `distance` expressed in the vehicle's odometer unit.
    func litersPer100km(unit: OdometerUnit) -> Double? {
        let km = unit.toKilometers(distance)
        guard km > 0, liters > 0 else { return nil }
        return liters / km * 100
    }

    func mpg(unit: OdometerUnit) -> Double? {
        guard let l100 = litersPer100km(unit: unit), l100 > 0 else { return nil }
        // UK imperial MPG from L/100km
        return 282.481 / l100
    }

    func costPerDistance(unit: OdometerUnit) -> Double? {
        guard distance > 0 else { return nil }
        return cost / distance
    }
}

struct VehicleFuelStats: Sendable, Equatable {
    var fillUpCount: Int
    var totalLiters: Double
    var totalSpend: Double
    var totalDistance: Double
    var averagePricePerLiter: Double?
    var lastSegment: ConsumptionSegment?
    var averageLitersPer100km: Double?
    var averageMPG: Double?
    var averageCostPerDistance: Double?
    var spendThisMonth: Double
    var spendThisYear: Double
    var segments: [ConsumptionSegment]
}

enum FuelStats {
    /// Full-tank method: each segment runs from one full tank to the next full tank.
    /// Liters and cost include every fill-up after the start full (partials + ending full).
    /// A fill-up marked `skipped` breaks the chain (missed fill-up).
    static func segments(from fillUps: [FillUpSnapshot]) -> [ConsumptionSegment] {
        segmentEntries(from: fillUps).map(\.segment)
    }

    /// Segments keyed by the ending full-tank fill-up id.
    static func segmentsByEndingFillUpID(from fillUps: [FillUpSnapshot]) -> [UUID: ConsumptionSegment] {
        Dictionary(uniqueKeysWithValues: segmentEntries(from: fillUps).map { ($0.id, $0.segment) })
    }

    private static func segmentEntries(from fillUps: [FillUpSnapshot]) -> [(id: UUID, segment: ConsumptionSegment)] {
        let ordered = fillUps.sorted {
            if $0.odometer != $1.odometer {
                return $0.odometer < $1.odometer
            }
            return $0.date < $1.date
        }

        var result: [(id: UUID, segment: ConsumptionSegment)] = []
        var startIndex: Int?

        for (index, fill) in ordered.enumerated() {
            if fill.skipped {
                startIndex = nil
                continue
            }

            guard fill.isFullTank else { continue }

            if let start = startIndex {
                let slice = ordered[(start + 1)...index]
                let liters = slice.reduce(0) { $0 + $1.liters }
                let cost = slice.reduce(0) { $0 + $1.totalCost }
                let startOdo = ordered[start].odometer
                let endOdo = fill.odometer
                if endOdo > startOdo, liters > 0 {
                    result.append(
                        (
                            id: fill.id,
                            segment: ConsumptionSegment(
                                startOdometer: startOdo,
                                endOdometer: endOdo,
                                liters: liters,
                                cost: cost
                            )
                        )
                    )
                }
            }

            startIndex = index
        }

        return result
    }

    static func compute(
        fillUps: [FillUpSnapshot],
        unit: OdometerUnit,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> VehicleFuelStats {
        let ordered = fillUps.sorted {
            if $0.odometer != $1.odometer {
                return $0.odometer < $1.odometer
            }
            return $0.date < $1.date
        }

        let segments = segments(from: ordered)
        let totalLiters = ordered.reduce(0) { $0 + $1.liters }
        let totalSpend = ordered.reduce(0) { $0 + $1.totalCost }
        let totalDistance = segments.reduce(0) { $0 + $1.distance }

        let priced = ordered.filter { $0.liters > 0 }
        let averagePrice: Double? = {
            guard !priced.isEmpty else { return nil }
            let sum = priced.reduce(0) { $0 + ($1.totalCost / $1.liters) }
            return sum / Double(priced.count)
        }()

        let weightedLiters = segments.reduce(0) { $0 + $1.liters }
        let weightedKm = segments.reduce(0) { $0 + unit.toKilometers($1.distance) }
        let averageL100: Double? = {
            guard weightedKm > 0, weightedLiters > 0 else { return nil }
            return weightedLiters / weightedKm * 100
        }()
        let averageMPG: Double? = {
            guard let l100 = averageL100, l100 > 0 else { return nil }
            return 282.481 / l100
        }()
        let averageCostPerDistance: Double? = {
            guard totalDistance > 0 else { return nil }
            let segmentCost = segments.reduce(0) { $0 + $1.cost }
            return segmentCost / totalDistance
        }()

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        let spendThisMonth = ordered
            .filter { $0.date >= monthStart }
            .reduce(0) { $0 + $1.totalCost }
        let spendThisYear = ordered
            .filter { $0.date >= yearStart }
            .reduce(0) { $0 + $1.totalCost }

        return VehicleFuelStats(
            fillUpCount: ordered.count,
            totalLiters: totalLiters,
            totalSpend: totalSpend,
            totalDistance: totalDistance,
            averagePricePerLiter: averagePrice,
            lastSegment: segments.last,
            averageLitersPer100km: averageL100,
            averageMPG: averageMPG,
            averageCostPerDistance: averageCostPerDistance,
            spendThisMonth: spendThisMonth,
            spendThisYear: spendThisYear,
            segments: segments
        )
    }

    static func compute(vehicle: Vehicle, calendar: Calendar = .current, now: Date = .now) -> VehicleFuelStats {
        let snapshots = vehicle.fillUps.map {
            FillUpSnapshot(
                id: $0.id,
                date: $0.date,
                odometer: $0.odometer,
                liters: $0.liters,
                totalCost: $0.totalCost,
                isFullTank: $0.isFullTank,
                skipped: $0.skipped
            )
        }
        return compute(fillUps: snapshots, unit: vehicle.odometerUnit, calendar: calendar, now: now)
    }
}
