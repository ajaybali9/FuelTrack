import Foundation

struct UsedStationSummary: Identifiable, Hashable, Sendable {
    var id: String
    var displayName: String
    var visitCount: Int
    var lastVisit: Date
    var lastLiters: Double
    var lastCost: Double
    var lastCurrency: CurrencyCode
    var totalSpend: Double

    var lastPricePerLiter: Double? {
        guard lastLiters > 0 else { return nil }
        return lastCost / lastLiters
    }
}

enum UsedStations {
    static func summarize(from fillUps: [FillUp]) -> [UsedStationSummary] {
        var buckets: [String: (display: String, count: Int, last: FillUp, spend: Double)] = [:]

        for fill in fillUps {
            let raw = fill.station.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }
            let key = normalize(raw)
            if var existing = buckets[key] {
                existing.count += 1
                existing.spend += fill.totalCost
                if fill.date > existing.last.date {
                    existing.last = fill
                    existing.display = raw
                }
                buckets[key] = existing
            } else {
                buckets[key] = (raw, 1, fill, fill.totalCost)
            }
        }

        return buckets.map { key, value in
            UsedStationSummary(
                id: key,
                displayName: value.display,
                visitCount: value.count,
                lastVisit: value.last.date,
                lastLiters: value.last.liters,
                lastCost: value.last.totalCost,
                lastCurrency: value.last.currencyCode,
                totalSpend: value.spend
            )
        }
        .sorted {
            if $0.visitCount != $1.visitCount { return $0.visitCount > $1.visitCount }
            return $0.lastVisit > $1.lastVisit
        }
    }

    static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func matches(_ used: UsedStationSummary, nearby: NearbyStation) -> Bool {
        let usedKey = used.id
        let candidates = [
            nearby.name,
            nearby.brand,
            nearby.postcode,
            [nearby.brand, nearby.name].filter { !$0.isEmpty }.joined(separator: " "),
            [nearby.name, nearby.postcode].filter { !$0.isEmpty }.joined(separator: " "),
            [nearby.brand, nearby.name, nearby.postcode].filter { !$0.isEmpty }.joined(separator: " · "),
        ]
        .map(normalize)
        .filter { !$0.isEmpty }

        for candidate in candidates {
            if usedKey.contains(candidate) || candidate.contains(usedKey) {
                return true
            }
            // Postcode-only match when both mention it.
            let post = normalize(nearby.postcode)
            if !post.isEmpty, usedKey.contains(post), candidate.contains(post) {
                return true
            }
        }
        return false
    }
}
