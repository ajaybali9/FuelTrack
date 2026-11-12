import Foundation

enum FuelioCSVExporter {
    static func export(vehicle: Vehicle) -> String {
        var lines: [String] = []
        lines.append("\"## Vehicle\"")
        lines.append("\"Name\",\"Description\",\"DistUnit\",\"FuelUnit\",\"ConsumptionUnit\",\"ImportCSVDateFormat\",\"VIN\",\"Insurance\",\"Plate\",\"Make\",\"Model\",\"Year\",\"TankCount\",\"Tank1Type\",\"Tank2Type\"")
        let dist = vehicle.odometerUnit == .kilometers ? "2" : "1"
        let desc = csv(vehicle.notes)
        lines.append("\"\(csv(vehicle.name))\",\"\(desc)\",\"\(dist)\",\"2\",\"2\",\"yyyy-MM-dd\",\"\",\"\",\"\",\"\(csv(vehicle.make))\",\"\(csv(vehicle.model))\",\"\",\"1\",\"110\",\"0\"")

        lines.append("\"## Log\"")
        lines.append("\"Date\",\"Odo (\(vehicle.odometerUnit.shortLabel))\",\"Fuel (l)\",\"Full\",\"Price\",\"mpg\",\"latitude\",\"longitude\",\"City\",\"Notes\",\"Missed\",\"TankNumber\",\"FuelType\",\"VolumePrice\",\"StationID\"")
        for fill in vehicle.sortedFillUps {
            let date = Self.dateString(fill.date)
            let full = fill.isFullTank ? "1" : "0"
            let missed = fill.skipped ? "1" : "0"
            let ppl = fill.pricePerLiter.map { String(format: "%.3f", $0) } ?? ""
            lines.append(
                "\"\(date)\",\"\(fill.odometer)\",\"\(fill.liters)\",\"\(full)\",\"\(fill.totalCost)\",\"\",\"\",\"\",\"\(csv(fill.station))\",\"\(csv(fill.note))\",\"\(missed)\",\"1\",\"110\",\"\(ppl)\",\"\""
            )
        }

        lines.append("\"## CostCategories\"")
        lines.append("\"CostTypeID\",\"Name\",\"priority\",\"color\"")
        for (index, category) in CostCategory.allCases.enumerated() {
            lines.append("\"\(index + 1)\",\"\(csv(category.displayName))\",\"\(index + 1)\",\"#9E9E9E\"")
        }

        lines.append("\"## Costs\"")
        lines.append("\"CostTitle\",\"Date\",\"Odo\",\"CostTypeID\",\"Notes\",\"Cost\",\"flag\",\"idR\",\"read\",\"RemindOdo\",\"RemindDate\",\"isTemplate\",\"RepeatOdo\",\"RepeatMonths\",\"isIncome\",\"UniqueId\"")
        for (index, cost) in vehicle.sortedCosts.enumerated() {
            let date = Self.dateString(cost.date)
            let typeID = (CostCategory.allCases.firstIndex(where: { $0.rawValue == cost.categoryKey }) ?? CostCategory.allCases.firstIndex(of: .other) ?? 0) + 1
            let odo = cost.odometer.map { String($0) } ?? ""
            lines.append(
                "\"\(csv(cost.title))\",\"\(date)\",\"\(odo)\",\"\(typeID)\",\"\(csv(cost.note))\",\"\(cost.amount)\",\"0\",\"\",\"0\",\"\",\"\",\"0\",\"\",\"\",\"0\",\"\(index + 1)\""
            )
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func csv(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
