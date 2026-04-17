import Foundation

/// Which field the fuzzy match came from — governs which string to
/// highlight in the UI.
enum MatchField: Hashable { case title, url }

struct SearchResult: Identifiable, Hashable {
    let tab: Tab
    let score: Int
    let matchIndices: [Int]
    let matchField: MatchField

    var id: UUID { tab.id }

    static func rank(tabs: [Tab], query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return tabs.map {
                SearchResult(tab: $0, score: 0, matchIndices: [], matchField: .title)
            }
        }

        let ranked = tabs.compactMap { tab -> SearchResult? in
            let titleHit = FuzzyMatcher.match(pattern: trimmed, in: tab.title)
            let urlHit   = FuzzyMatcher.match(pattern: trimmed, in: tab.url)

            // Title matches outrank URL matches even when URL scores higher,
            // because the title is what the user reads first. Tie-break:
            // if only URL matches, we still keep the row.
            if let t = titleHit {
                return SearchResult(tab: tab, score: t.score, matchIndices: t.indices, matchField: .title)
            }
            if let u = urlHit {
                // Penalise URL-only matches a bit so title matches float up.
                return SearchResult(tab: tab, score: u.score - 20, matchIndices: u.indices, matchField: .url)
            }
            return nil
        }
        return ranked.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.tab.title.localizedCaseInsensitiveCompare($1.tab.title) == .orderedAscending
        }
    }
}
