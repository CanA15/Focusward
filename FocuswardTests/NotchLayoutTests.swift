import XCTest
@testable import Focusward

final class NotchLayoutTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    func testFindsNoNotchOnADisplayWithoutOne() {
        XCTAssertNil(
            NotchLayout.notchFrame(screenFrame: screen, topInset: 0, leftAreaWidth: 662, rightAreaWidth: 662)
        )
        XCTAssertNil(
            NotchLayout.notchFrame(screenFrame: screen, topInset: 32, leftAreaWidth: nil, rightAreaWidth: nil)
        )
    }

    func testFindsTheNotchBetweenTheMenuBarAreas() {
        XCTAssertEqual(
            NotchLayout.notchFrame(screenFrame: screen, topInset: 32, leftAreaWidth: 662, rightAreaWidth: 662),
            CGRect(x: 662, y: 950, width: 188, height: 32)
        )

        let offsetScreen = CGRect(x: -1728, y: 400, width: 1728, height: 1117)
        XCTAssertEqual(
            NotchLayout.notchFrame(screenFrame: offsetScreen, topInset: 38, leftAreaWidth: 760, rightAreaWidth: 760),
            CGRect(x: -968, y: 1479, width: 208, height: 38)
        )
    }

    func testCollapsedPanelWrapsTheNotch() {
        for notch in notches {
            let frame = NotchLayout.panelFrame(notch: notch, isExpanded: false, rowCount: 2)

            XCTAssertEqual(frame.midX, notch.midX)
            XCTAssertEqual(frame.maxY, notch.maxY)
            XCTAssertEqual(frame.height, notch.height)
            XCTAssertGreaterThan(frame.width, notch.width)
        }
    }

    func testExpandedPanelGrowsDownFromTheNotch() {
        for notch in notches {
            let collapsed = NotchLayout.panelFrame(notch: notch, isExpanded: false, rowCount: 2)
            let twoRows = NotchLayout.panelFrame(notch: notch, isExpanded: true, rowCount: 2)
            let threeRows = NotchLayout.panelFrame(notch: notch, isExpanded: true, rowCount: 3)

            XCTAssertEqual(twoRows.midX, notch.midX)
            XCTAssertEqual(twoRows.maxY, notch.maxY)
            XCTAssertTrue(twoRows.contains(collapsed))
            XCTAssertEqual(threeRows.height - twoRows.height, NotchLayout.rowHeight)
        }
    }

    // The notch sizes differ between MacBook models and display scale settings.
    private var notches: [CGRect] {
        [
            CGRect(x: 662, y: 950, width: 188, height: 32),
            CGRect(x: -968, y: 1479, width: 208, height: 38),
            CGRect(x: 500, y: 800, width: 400, height: 44),
        ]
    }
}
