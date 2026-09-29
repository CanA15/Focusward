import XCTest
@testable import Focusward

final class FocusDurationTests: XCTestCase {
    func testCreatesCustomDurationsFromHoursAndMinutes() {
        XCTAssertEqual(FocusDuration.totalMinutes(hours: 4, minutes: 0), 240)
        XCTAssertEqual(FocusDuration.totalMinutes(hours: 6, minutes: 35), 395)
    }

    func testClampsCustomDurationToThirtyDays() {
        XCTAssertEqual(FocusDuration.totalMinutes(hours: -1, minutes: -5), 0)
        XCTAssertEqual(
            FocusDuration.totalMinutes(hours: 900, minutes: 45),
            FocusDuration.maximumHours * 60
        )
    }

    func testFormatsDurationLabels() {
        XCTAssertEqual(FocusDuration.label(totalMinutes: 25), "25 min")
        XCTAssertEqual(FocusDuration.label(totalMinutes: 60), "1 hour")
        XCTAssertEqual(FocusDuration.label(totalMinutes: 270), "4 hours 30 min")
        XCTAssertEqual(FocusDuration.label(totalMinutes: 1_500), "1 day 1 hour")
        XCTAssertEqual(FocusDuration.label(totalMinutes: 43_200), "30 days")
        XCTAssertEqual(FocusDuration.compactLabel(totalMinutes: 240), "4h")
    }

    func testCalculatesTheRemainingFractionOfASession() {
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let end = start.addingTimeInterval(3_600)

        XCTAssertEqual(FocusDuration.remainingFraction(start: start, end: end, at: start), 1)
        XCTAssertEqual(
            FocusDuration.remainingFraction(start: start, end: end, at: start.addingTimeInterval(900)),
            0.75
        )
        XCTAssertEqual(FocusDuration.remainingFraction(start: start, end: end, at: end), 0)
    }

    func testKeepsTheRemainingFractionBetweenZeroAndOne() {
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let end = start.addingTimeInterval(3_600)

        XCTAssertEqual(
            FocusDuration.remainingFraction(start: start, end: end, at: start.addingTimeInterval(-60)),
            1
        )
        XCTAssertEqual(
            FocusDuration.remainingFraction(start: start, end: end, at: end.addingTimeInterval(60)),
            0
        )
        XCTAssertEqual(FocusDuration.remainingFraction(start: end, end: end, at: start), 0)
    }
}
