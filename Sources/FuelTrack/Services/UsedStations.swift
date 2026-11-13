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
            let external = fill.stationExternalId.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty { continue }
            let key = external.isEmpty ? normalize(raw) : "station:\(external)"
            if var existing = buckets[key] {
                existing.count += 1
                existing.spend += fill.totalCost
                existing.display = richerName(existing.display, raw)
                if fill.date > existing.last.date {
                    existing.last = fill
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

    /// Compact UK postcode form, e.g. "rg21 7qw" → "rg217qw".
    static func compactPostcode(_ text: String) -> String {
        normalize(text).replacingOccurrences(of: " ", with: "")
    }

    static func matches(_ used: UsedStationSummary, nearby: NearbyStation) -> Bool {
        matchScore(used, nearby: nearby) > 0
    }

    /// Prefer the strongest location-aware match, not the first brand hit.
    static func bestMatch(for used: UsedStationSummary, in stations: [NearbyStation]) -> NearbyStation? {
        stations
            .map { ($0, matchScore(used, nearby: $0)) }
            .filter { $0.1 > 0 }
            .max { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return (lhs.0.distanceMiles ?? .greatestFiniteMagnitude) > (rhs.0.distanceMiles ?? .greatestFiniteMagnitude)
            }?
            .0
    }

    /// Score a candidate using whole words and a full postcode.
    /// A town name or a brand on its own is not a match.
    static func matchScore(_ used: UsedStationSummary, nearby: NearbyStation) -> Int {
        let usedTokens = tokens(used.displayName)
        let nameTokens = tokens(nearby.name)
        let brandTokens = tokens(nearby.brand)
        let cityTokens = tokens(nearby.city)

        var score = 0
        var postcodeHit = false
        var cityHit = false
        var distinctiveHit = false

        if let usedPost = ukPostcode(in: used.displayName),
           let nearbyPost = ukPostcode(in: nearby.postcode),
           usedPost == nearbyPost {
            score += 100
            postcodeHit = true
        }

        if !cityTokens.isEmpty, !cityTokens.isDisjoint(with: usedTokens) {
            score += 25
            cityHit = true
        }

        let distinctiveName = nameTokens.subtracting(brandTokens).subtracting(cityTokens).subtracting(genericTokens)
        let distinctiveUsed = usedTokens.subtracting(brandTokens).subtracting(cityTokens).subtracting(genericTokens)
        let shared = distinctiveName.intersection(distinctiveUsed)
        if !shared.isEmpty {
            score += min(60, shared.count * 30)
            distinctiveHit = true
        }

        let brandHit = !brandTokens.isEmpty && brandTokens.isSubset(of: usedTokens)
        if brandHit, postcodeHit || cityHit || distinctiveHit {
            score += 20
        }

        let longDistinctive = shared.contains { $0.count >= 5 }
        let strong = postcodeHit
            || (distinctiveHit && (brandHit || cityHit || longDistinctive))
            || (brandHit && cityHit)
        guard strong, score >= 50 else { return 0 }
        return score
    }

    static func tokens(_ text: String) -> Set<String> {
        let parts = normalize(text)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 2 }
        return Set(parts)
    }

    /// First full UK postcode in `text`, compacted, so "RG21 7QW" and "rg217qw" compare equal.
    static func ukPostcode(in text: String) -> String? {
        guard let range = text.range(of: postcodePattern, options: .regularExpression) else { return nil }
        let compact = compactPostcode(String(text[range]))
        return compact.isEmpty ? nil : compact
    }

    private static let postcodePattern = #"[A-Za-z]{1,2}[0-9][0-9A-Za-z]?[[:space:]]*[0-9][A-Za-z]{2}"#

    private static let genericTokens: Set<String> = [
        "road", "street", "lane", "way", "close", "drive", "avenue",
        "service", "services", "station", "garage", "filling", "petrol", "fuel",
        "the", "and",
    ]

    private static func richerName(_ current: String, _ candidate: String) -> String {
        let currentCount = tokens(current).count
        let candidateCount = tokens(candidate).count
        if candidateCount != currentCount { return candidateCount > currentCount ? candidate : current }
        return candidate.count > current.count ? candidate : current
    }
}
