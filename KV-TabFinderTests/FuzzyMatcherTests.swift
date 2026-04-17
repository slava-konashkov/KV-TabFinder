import XCTest
@testable import KVTabFinder

final class FuzzyMatcherTests: XCTestCase {
    func testEmptyPatternMatchesAnything() {
        let result = FuzzyMatcher.match(pattern: "", in: "GitHub")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.indices, [])
    }

    func testSimpleSubsequence() {
        let r = FuzzyMatcher.match(pattern: "ghpr", in: "GitHub Pull Request")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.indices.count, 4)
        // Should match G, H (from GitHub), P (Pull), R (Request)
        let chars = Array("GitHub Pull Request")
        let matched = String(r!.indices.map { chars[$0] })
        XCTAssertEqual(matched.lowercased(), "ghpr")
    }

    func testNoMatchReturnsNil() {
        let r = FuzzyMatcher.match(pattern: "xyz", in: "GitHub")
        XCTAssertNil(r)
    }

    func testCaseInsensitive() {
        let r = FuzzyMatcher.match(pattern: "GH", in: "github")
        XCTAssertNotNil(r)
    }

    func testConsecutiveBonusOutranksSkips() {
        let a = FuzzyMatcher.match(pattern: "git", in: "GitHub")!
        let b = FuzzyMatcher.match(pattern: "git", in: "Geography Information Toolkit")!
        XCTAssertGreaterThan(a.score, b.score,
            "Consecutive match in GitHub should outscore scattered match")
    }

    func testPrefixBonus() {
        let prefix = FuzzyMatcher.match(pattern: "git", in: "GitHub")!
        let middle = FuzzyMatcher.match(pattern: "git", in: "my-git-repo")!
        XCTAssertGreaterThan(prefix.score, middle.score)
    }
}
