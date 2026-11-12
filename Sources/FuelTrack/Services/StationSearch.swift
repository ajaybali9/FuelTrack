import Foundation

enum StationSearch {
    /// Matches when every search token appears somewhere across the haystack fields.
    /// So "tesco basingstoke" matches name "Tesco" + city "Basingstoke".
    static func matches(query: String, fields: [String]) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }

        let haystack = fields
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let tokens = q
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .split { $0.isWhitespace || $0 == "," || $0 == "·" || $0 == "-" }
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return true }
        return tokens.allSatisfy { haystack.contains($0) }
    }

    static func matches(_ station: NearbyStation, query: String) -> Bool {
        matches(
            query: query,
            fields: [station.name, station.brand, station.address, station.city, station.postcode]
        )
    }

    static func matchesUsed(_ summary: UsedStationSummary, query: String) -> Bool {
        matches(query: query, fields: [summary.displayName])
    }
}
