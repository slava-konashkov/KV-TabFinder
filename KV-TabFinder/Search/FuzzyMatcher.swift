import Foundation

enum FuzzyMatcher {
    /// Greedy subsequence match, case-insensitive.
    /// Returns nil if `pattern` cannot be embedded as a subsequence of `text`.
    /// Score rewards consecutive matches and penalises skipped characters.
    static func match(pattern: String, in text: String) -> (score: Int, indices: [Int])? {
        if pattern.isEmpty { return (0, []) }

        let p = Array(pattern.lowercased())
        let t = Array(text.lowercased())
        guard !t.isEmpty else { return nil }

        var indices: [Int] = []
        indices.reserveCapacity(p.count)
        var pi = 0
        var consecutive = 0
        var score = 0

        for (ti, char) in t.enumerated() {
            guard pi < p.count else { break }
            if char == p[pi] {
                indices.append(ti)
                pi += 1
                consecutive += 1
                score += 10 + consecutive * 5
                if ti == 0 { score += 15 } // prefix bonus
                if ti > 0, t[ti - 1] == " " || t[ti - 1] == "-" || t[ti - 1] == "_" {
                    score += 8 // word-start bonus
                }
            } else {
                consecutive = 0
                score -= 1
            }
        }

        guard pi == p.count else { return nil }
        return (score, indices)
    }
}
