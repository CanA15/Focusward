import XCTest
@testable import Focusward

final class SafariAutomationTests: XCTestCase {
    func testReadsEveryTabURLInWindowAndTabOrder() throws {
        let reply = windows([
            ["https://youtube.com/watch?v=1", "https://example.com"],
            ["https://reddit.com/r/swift"],
        ])

        let snapshots = try SafariAutomation.snapshots(fromWindowTabURLs: reply)

        XCTAssertEqual(
            snapshots,
            [
                SafariTabSnapshot(windowIndex: 1, tabIndex: 1, url: "https://youtube.com/watch?v=1"),
                SafariTabSnapshot(windowIndex: 1, tabIndex: 2, url: "https://example.com"),
                SafariTabSnapshot(windowIndex: 2, tabIndex: 1, url: "https://reddit.com/r/swift"),
            ]
        )
    }

    func testSkipsTabsWithoutAURLAndKeepsTheTabNumbers() throws {
        let reply = windows([[nil, "https://youtube.com"], []])

        let snapshots = try SafariAutomation.snapshots(fromWindowTabURLs: reply)

        XCTAssertEqual(snapshots, [SafariTabSnapshot(windowIndex: 1, tabIndex: 2, url: "https://youtube.com")])
    }

    func testRejectsAReplyThatIsNotAWindowList() {
        XCTAssertThrowsError(
            try SafariAutomation.snapshots(fromWindowTabURLs: NSAppleEventDescriptor(string: "https://youtube.com"))
        )

        let tabNotInAWindowList = NSAppleEventDescriptor.list()
        tabNotInAWindowList.insert(NSAppleEventDescriptor(string: "https://youtube.com"), at: 0)
        XCTAssertThrowsError(try SafariAutomation.snapshots(fromWindowTabURLs: tabNotInAWindowList))
    }

    // Safari replies with "missing value" ('msng') for a tab that has no URL.
    private let missingValue: OSType = 0x6D73_6E67

    private func windows(_ urls: [[String?]]) -> NSAppleEventDescriptor {
        let windowList = NSAppleEventDescriptor.list()
        for tabURLs in urls {
            let tabList = NSAppleEventDescriptor.list()
            for url in tabURLs {
                tabList.insert(
                    url.map { NSAppleEventDescriptor(string: $0) } ?? NSAppleEventDescriptor(typeCode: missingValue),
                    at: 0
                )
            }
            windowList.insert(tabList, at: 0)
        }
        return windowList
    }
}
