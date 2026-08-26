import XCTest
@testable import Focusward

final class DailyLimitsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testCountsOnlyActiveUseForAMatchingSite() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = DailyLimits(now: start, calendar: calendar)

        XCTAssertTrue(
            limits.addSite(
                domain: "youtube.com",
                allowanceMinutes: 30,
                at: start,
                calendar: calendar
            )
        )

        limits.recordUsage(
            hostname: "youtube.com",
            duration: 60,
            at: start.addingTimeInterval(60),
            calendar: calendar
        )
        XCTAssertEqual(limits.site(for: "youtube.com")?.usedSeconds, 0)

        limits.setActive(true, at: start, calendar: calendar)
        limits.recordUsage(
            hostname: nil,
            duration: 60,
            at: start.addingTimeInterval(60),
            calendar: calendar
        )
        limits.recordUsage(
            hostname: "example.com",
            duration: 60,
            at: start.addingTimeInterval(120),
            calendar: calendar
        )
        limits.recordUsage(
            hostname: "www.youtube.com",
            duration: 60,
            at: start.addingTimeInterval(180),
            calendar: calendar
        )

        XCTAssertEqual(limits.site(for: "youtube.com")?.usedSeconds, 60)
    }

    func testBlocksASiteWhenItsAllowanceIsEmpty() throws {
        let start = try date(2026, 8, 27, 10, 0)
        let exhaustedAt = start.addingTimeInterval(60)
        var limits = DailyLimits(now: start, calendar: calendar)

        XCTAssertTrue(
            limits.addSite(
                domain: "youtube.com",
                allowanceMinutes: 1,
                at: start,
                calendar: calendar
            )
        )
        limits.setActive(true, at: start, calendar: calendar)
        limits.recordUsage(
            hostname: "youtube.com",
            duration: 90,
            at: exhaustedAt,
            calendar: calendar
        )

        let site = try XCTUnwrap(limits.blockingSite(for: "m.youtube.com"))
        XCTAssertEqual(site.usedSeconds, 60)
        XCTAssertEqual(site.remainingSeconds, 0)
        XCTAssertEqual(site.blockedSince, exhaustedAt)
    }

    func testResetsAllUsageAtLocalMidnight() throws {
        let start = try date(2026, 8, 27, 23, 58)
        let nextDay = try date(2026, 8, 28, 0, 1)
        var limits = DailyLimits(now: start, calendar: calendar)

        XCTAssertTrue(
            limits.addSite(
                domain: "youtube.com",
                allowanceMinutes: 1,
                at: start,
                calendar: calendar
            )
        )
        limits.setActive(true, at: start, calendar: calendar)
        limits.recordUsage(
            hostname: "youtube.com",
            duration: 60,
            at: start.addingTimeInterval(60),
            calendar: calendar
        )

        limits.refresh(at: nextDay, calendar: calendar)

        let site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertEqual(site.usedSeconds, 0)
        XCTAssertNil(site.blockedSince)
        XCTAssertNil(limits.blockingSite(for: "youtube.com"))
        XCTAssertEqual(limits.periodStart, calendar.startOfDay(for: nextDay))
    }

    func testLocksConfigurationWhileDailyLimitsAreActive() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = DailyLimits(now: start, calendar: calendar)

        XCTAssertTrue(
            limits.addSite(
                domain: "youtube.com",
                allowanceMinutes: 30,
                at: start,
                calendar: calendar
            )
        )
        limits.setActive(true, at: start, calendar: calendar)

        XCTAssertFalse(
            limits.addSite(
                domain: "reddit.com",
                allowanceMinutes: 15,
                at: start,
                calendar: calendar
            )
        )
        XCTAssertFalse(limits.updateAllowance(for: "youtube.com", minutes: 60))
        XCTAssertFalse(limits.removeSite(domain: "youtube.com"))

        limits.setActive(false, at: start, calendar: calendar)

        XCTAssertTrue(limits.updateAllowance(for: "youtube.com", minutes: 60))
        XCTAssertTrue(limits.removeSite(domain: "youtube.com"))
    }

    func testDeactivationKeepsUsedTime() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = DailyLimits(now: start, calendar: calendar)

        XCTAssertTrue(
            limits.addSite(
                domain: "youtube.com",
                allowanceMinutes: 30,
                at: start,
                calendar: calendar
            )
        )
        limits.setActive(true, at: start, calendar: calendar)
        limits.recordUsage(
            hostname: "youtube.com",
            duration: 120,
            at: start.addingTimeInterval(120),
            calendar: calendar
        )
        limits.setActive(false, at: start.addingTimeInterval(180), calendar: calendar)

        let site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertEqual(site.usedSeconds, 120)
        XCTAssertNil(site.blockedSince)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }
}
