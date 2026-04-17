import Foundation

struct SearchResult: Identifiable, Hashable {
    let tab: Tab
    let score: Int
    let matchIndices: [Int]

    var id: UUID { tab.id }

    static func rank(tabs: [Tab], query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return tabs.map { SearchResult(tab: $0, score: 0, matchIndices: []) }
        }
        let ranked = tabs.compactMap { tab -> SearchResult? in
            guard let m = FuzzyMatcher.match(pattern: trimmed, in: tab.title) else { return nil }
            return SearchResult(tab: tab, score: m.score, matchIndices: m.indices)
        }
        return ranked.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.tab.title.localizedCaseInsensitiveCompare($1.tab.title) == .orderedAscending
        }
    }
}
