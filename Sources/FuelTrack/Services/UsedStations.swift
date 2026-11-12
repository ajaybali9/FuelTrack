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

    /// Score a candidate. Brand alone is never enough — need postcode, town, or distinctive name.
    static func matchScore(_ used: UsedStationSummary, nearby: NearbyStation) -> Int {
        let usedKey = used.id
        let usedCompact = compactPostcode(used.displayName)
        let name = normalize(nearby.name)
        let brand = normalize(nearby.brand)
        let city = normalize(nearby.city)
        let post = normalize(nearby.postcode)
        let postCompact = compactPostcode(nearby.postcode)

        var score = 0
        var hasLocationSignal = false

        if !postCompact.isEmpty, usedCompact.contains(postCompact) {
            score += 100
            hasLocationSignal = true
        } else if !post.isEmpty, usedKey.contains(post) {
            score += 90
            hasLocationSignal = true
        }

        if !city.isEmpty, usedKey.contains(city) {
            score += 60
            hasLocationSignal = true
        }

        let brandTokens = tokens(brand)
        let nameTokens = tokens(name).subtracting(brandTokens)
        let usedTokens = tokens(usedKey)
        let distinctive = nameTokens.intersection(usedTokens)

        if !name.isEmpty {
            if usedKey == name || usedKey.contains(name) || name.contains(usedKey) {
                // Full name overlap still needs a place clue unless the used string already embeds locality.
                score += 35
            }
            if !distinctive.isEmpty {
                score += min(40, distinctive.count * 15)
                // Tokens like "basingstoke", street names, store numbers count as location-ish.
                if distinctive.contains(where: { $0.count >= 5 }) {
                    hasLocationSignal = true
                }
            }
        }

        if !brand.isEmpty, usedKey.contains(brand) || brandTokens.isSubset(of: usedTokens) {
            // Brand is only a bonus once place/name already matches.
            if hasLocationSignal || score >= 35 {
                score += 10
            }
        }

        // Reject weak brand-only matches (e.g. any Morrisons).
        guard hasLocationSignal, score >= 50 else { return 0 }
        return score
    }

    private static func tokens(_ text: String) -> Set<String> {
        let parts = normalize(text)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 2 }
        return Set(parts)
    }
}
