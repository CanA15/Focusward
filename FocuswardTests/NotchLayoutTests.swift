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

    func testCollapsedPanelCoversOnlyTheNotch() {
        for notch in notches {
            XCTAssertEqual(NotchLayout.panelFrame(notch: notch, isExpanded: false, breakCount: 2), notch)
        }
    }

    func testExpandedPanelGrowsDownFromTheNotch() {
        for notch in notches {
            let collapsed = NotchLayout.panelFrame(notch: notch, isExpanded: false, breakCount: 1)
            let oneBreak = NotchLayout.panelFrame(notch: notch, isExpanded: true, breakCount: 1)
            let twoBreaks = NotchLayout.panelFrame(notch: notch, isExpanded: true, breakCount: 2)

            XCTAssertEqual(oneBreak.midX, notch.midX)
            XCTAssertEqual(oneBreak.maxY, notch.maxY)
            XCTAssertTrue(oneBreak.contains(collapsed))
            XCTAssertEqual(twoBreaks.height - oneBreak.height, NotchLayout.rowHeight)
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
