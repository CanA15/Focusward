import XCTest
@testable import Focusward

final class WebsiteTileTests: XCTestCase {
    func testShowsTheFirstLetterOfTheDomain() {
        XCTAssertEqual(WebsiteTile.letter(for: "youtube.com"), "Y")
        XCTAssertEqual(WebsiteTile.letter(for: "x.com"), "X")
    }

    // Swift randomizes String.hashValue for each process, so a tile must not use it.
    func testGivesAWebsiteTheSameColorOnEveryLaunch() {
        XCTAssertEqual(WebsiteTile.colorIndex(for: "youtube.com"), 3)
        XCTAssertEqual(WebsiteTile.colorIndex(for: "reddit.com"), 1)
    }

    func testKeepsTheColorIndexInThePalette() {
        for domain in ["a.com", "instagram.com", "news.ycombinator.com", "x.com"] {
            XCTAssertTrue(0 ..< WebsiteTile.colorCount ~= WebsiteTile.colorIndex(for: domain))
        }
    }
}
