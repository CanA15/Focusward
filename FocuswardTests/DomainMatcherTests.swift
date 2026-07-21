import XCTest
@testable import Focusward

final class DomainMatcherTests: XCTestCase {
    func testNormalizesDomainsAndURLs() {
        XCTAssertEqual(DomainMatcher.normalizeRule(" youtube.com "), "youtube.com")
        XCTAssertEqual(
            DomainMatcher.normalizeRule("https://www.reddit.com/r/swift?sort=new"),
            "reddit.com"
        )
        XCTAssertEqual(DomainMatcher.normalizeRule("news.ycombinator.com."), "news.ycombinator.com")
    }

    func testRejectsValuesWithoutARegistrableShape() {
        XCTAssertNil(DomainMatcher.normalizeRule(""))
        XCTAssertNil(DomainMatcher.normalizeRule("localhost"))
        XCTAssertNil(DomainMatcher.normalizeRule("not a domain"))
    }

    func testBlocksExactDomainsAndSubdomainsOnly() {
        let rules = ["youtube.com", "reddit.com"]

        XCTAssertTrue(DomainMatcher.isBlocked(hostname: "youtube.com", by: rules))
        XCTAssertTrue(DomainMatcher.isBlocked(hostname: "m.youtube.com", by: rules))
        XCTAssertFalse(DomainMatcher.isBlocked(hostname: "notyoutube.com", by: rules))
        XCTAssertFalse(DomainMatcher.isBlocked(hostname: "example.com", by: rules))
    }

    func testExtractsOnlyTheHostnameFromATabURL() {
        XCTAssertEqual(
            DomainMatcher.hostname(from: "https://www.youtube.com/watch?v=private-value"),
            "www.youtube.com"
        )
        XCTAssertNil(DomainMatcher.hostname(from: "about:blank"))
    }
}
