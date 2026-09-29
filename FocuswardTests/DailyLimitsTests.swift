import XCTest
@testable import Focusward

final class DailyLimitsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testBlocksEveryListedSiteOnlyWhileActive() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = try limits(sites: ["youtube.com": 30], at: start, active: false)

        XCTAssertNil(limits.blockingSite(for: "youtube.com"))

        limits.setActive(true, at: start, calendar: calendar)

        XCTAssertEqual(limits.blockingSite(for: "m.youtube.com")?.domain, "youtube.com")
        XCTAssertNil(limits.blockingSite(for: "example.com"))
    }

    func testBreakOpensOnlyItsSiteUntilTheBreakEnds() throws {
        let start = try date(2026, 8, 27, 10, 0)
        let breakEnd = start.addingTimeInterval(10 * 60)
        var limits = try limits(sites: ["youtube.com": 30, "reddit.com": 30], at: start)

        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 10, at: start, calendar: calendar))

        limits.refresh(at: start.addingTimeInterval(5 * 60), calendar: calendar)
        XCTAssertNil(limits.blockingSite(for: "www.youtube.com"))
        XCTAssertNotNil(limits.blockingSite(for: "reddit.com"))

        limits.refresh(at: breakEnd, calendar: calendar)
        XCTAssertNotNil(limits.blockingSite(for: "youtube.com"))

        let site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertNil(site.activeBreak)
        XCTAssertEqual(site.usedSeconds, 10 * 60)
        XCTAssertEqual(site.remainingSeconds, 20 * 60)
        XCTAssertEqual(site.breakCount, 1)
    }

    func testListsOnlyTheSitesOnBreak() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = try limits(
            sites: ["example.com": 30, "reddit.com": 30, "youtube.com": 30],
            at: start
        )

        XCTAssertTrue(limits.sitesOnBreak.isEmpty)

        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 15, at: start, calendar: calendar))
        XCTAssertTrue(
            limits.startBreak(
                for: "reddit.com",
                minutes: 5,
                at: start.addingTimeInterval(60),
                calendar: calendar
            )
        )

        XCTAssertEqual(limits.sitesOnBreak.map(\.domain), ["reddit.com", "youtube.com"])
    }

    func testReportsTheWholeSecondsLeftInABreak() throws {
        let start = try date(2026, 8, 27, 10, 0)
        let dailyBreak = DailyBreak(start: start, end: start.addingTimeInterval(10 * 60))

        XCTAssertEqual(dailyBreak.secondsLeft(at: start), 600)
        XCTAssertEqual(dailyBreak.secondsLeft(at: start.addingTimeInterval(0.4)), 600)
        XCTAssertEqual(dailyBreak.secondsLeft(at: start.addingTimeInterval(599.5)), 1)
        XCTAssertEqual(dailyBreak.secondsLeft(at: start.addingTimeInterval(700)), 0)
    }

    func testRejectsABreakThatCannotStart() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = try limits(sites: ["youtube.com": 10], at: start, active: false)

        XCTAssertFalse(limits.startBreak(for: "youtube.com", minutes: 5, at: start, calendar: calendar))

        limits.setActive(true, at: start, calendar: calendar)

        XCTAssertFalse(limits.startBreak(for: "reddit.com", minutes: 5, at: start, calendar: calendar))
        XCTAssertFalse(limits.startBreak(for: "youtube.com", minutes: 0, at: start, calendar: calendar))
        XCTAssertFalse(limits.startBreak(for: "youtube.com", minutes: 11, at: start, calendar: calendar))
        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 10, at: start, calendar: calendar))
        XCTAssertFalse(limits.startBreak(for: "youtube.com", minutes: 1, at: start, calendar: calendar))

        let afterBreak = start.addingTimeInterval(10 * 60)
        XCTAssertFalse(limits.startBreak(for: "youtube.com", minutes: 1, at: afterBreak, calendar: calendar))
        XCTAssertEqual(limits.site(for: "youtube.com")?.breakCount, 1)
    }

    func testOffersBreakLengthsUpToTheTimeLeft() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = try limits(sites: ["youtube.com": 30], at: start)

        var site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertEqual(site.breakLengthOptions, [1, 5, 10, 15, 30])
        XCTAssertEqual(site.defaultBreakMinutes, 5)

        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 12, at: start, calendar: calendar))
        site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertEqual(site.breakLengthOptions, [1, 5, 10, 15, 18])

        limits.refresh(at: start.addingTimeInterval(12 * 60), calendar: calendar)
        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 15, at: start.addingTimeInterval(12 * 60), calendar: calendar))
        site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertEqual(site.breakLengthOptions, [1, 3])
        XCTAssertEqual(site.defaultBreakMinutes, 3)

        limits.refresh(at: start.addingTimeInterval(27 * 60), calendar: calendar)
        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 3, at: start.addingTimeInterval(27 * 60), calendar: calendar))
        site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertEqual(site.breakLengthOptions, [])
    }

    func testEndingABreakEarlyChargesTheWholeMinutesUsed() throws {
        let start = try date(2026, 8, 27, 10, 0)
        let endedAt = start.addingTimeInterval(150)
        var limits = try limits(sites: ["youtube.com": 30], at: start)

        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 10, at: start, calendar: calendar))
        XCTAssertTrue(limits.endBreak(for: "youtube.com", at: endedAt, calendar: calendar))

        let site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertNil(site.activeBreak)
        XCTAssertEqual(site.usedSeconds, 3 * 60)
        XCTAssertEqual(site.remainingMinutes(afterBreakOf: 20), 7)
        XCTAssertEqual(site.remainingMinutes(afterBreakOf: 30), 0)
        XCTAssertEqual(site.breakCount, 1)
        XCTAssertNotNil(limits.blockingSite(for: "youtube.com"))
        XCTAssertFalse(limits.endBreak(for: "youtube.com", at: endedAt, calendar: calendar))
    }

    func testMidnightEndsBreaksAndResetsBreakTime() throws {
        let start = try date(2026, 8, 27, 23, 55)
        let nextDay = try date(2026, 8, 28, 0, 1)
        var limits = try limits(sites: ["youtube.com": 30], at: start)

        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 10, at: start, calendar: calendar))
        limits.refresh(at: nextDay, calendar: calendar)

        let site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertNil(site.activeBreak)
        XCTAssertEqual(site.usedSeconds, 0)
        XCTAssertEqual(site.breakCount, 0)
        XCTAssertNotNil(limits.blockingSite(for: "youtube.com"))
        XCTAssertEqual(limits.periodStart, calendar.startOfDay(for: nextDay))
    }

    func testDeactivationEndsBreaksAndKeepsUsedTime() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = try limits(sites: ["youtube.com": 30], at: start)

        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 10, at: start, calendar: calendar))
        limits.setActive(false, at: start.addingTimeInterval(3 * 60), calendar: calendar)

        let site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertNil(site.activeBreak)
        XCTAssertEqual(site.usedSeconds, 3 * 60)
        XCTAssertEqual(site.breakCount, 1)
    }

    func testSessionRulesEndOnlyTheBreaksTheyOverlap() throws {
        let start = try date(2026, 8, 27, 10, 0)
        let sessionStart = start.addingTimeInterval(90)
        var limits = try limits(sites: ["youtube.com": 30, "reddit.com": 30], at: start)

        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 10, at: start, calendar: calendar))
        XCTAssertTrue(limits.startBreak(for: "reddit.com", minutes: 10, at: start, calendar: calendar))
        limits.endBreaks(overlapping: ["m.youtube.com", "example.com"], at: sessionStart, calendar: calendar)

        let youtube = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertNil(youtube.activeBreak)
        XCTAssertEqual(youtube.usedSeconds, 2 * 60)
        XCTAssertNotNil(limits.site(for: "reddit.com")?.activeBreak)
    }

    func testRejectsASiteThatOverlapsAnExistingRule() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = try limits(sites: ["m.youtube.com": 30], at: start, active: false)

        XCTAssertEqual(limits.overlappingSite(for: "youtube.com")?.domain, "m.youtube.com")
        XCTAssertFalse(limits.addSite(domain: "youtube.com", allowanceMinutes: 30, at: start, calendar: calendar))
        XCTAssertFalse(limits.addSite(domain: "a.m.youtube.com", allowanceMinutes: 30, at: start, calendar: calendar))
        XCTAssertNil(limits.overlappingSite(for: "www.youtube.com"))
        XCTAssertTrue(limits.addSite(domain: "music.youtube.com", allowanceMinutes: 30, at: start, calendar: calendar))
    }

    func testLocksConfigurationWhileDailyLimitsAreActive() throws {
        let start = try date(2026, 8, 27, 10, 0)
        var limits = try limits(sites: ["youtube.com": 30], at: start)

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

    func testDecodesDailyLimitsSavedBeforeBreaks() throws {
        let start = try date(2026, 8, 27, 10, 0)
        let saved = LegacyDailyLimits(
            isActive: true,
            periodStart: calendar.startOfDay(for: start),
            sites: [
                LegacyDailyLimitSite(
                    domain: "youtube.com",
                    allowanceMinutes: 30,
                    usedSeconds: 90,
                    blockedSince: start
                ),
            ]
        )
        let data = try PropertyListEncoder().encode(saved)

        let limits = try PropertyListDecoder().decode(DailyLimits.self, from: data)

        XCTAssertTrue(limits.isActive)
        let site = try XCTUnwrap(limits.site(for: "youtube.com"))
        XCTAssertEqual(site.allowanceMinutes, 30)
        XCTAssertEqual(site.usedSeconds, 90)
        XCTAssertEqual(site.usedMinutes, 2)
        XCTAssertEqual(site.remainingMinutes, 28)
        XCTAssertNil(site.activeBreak)
        XCTAssertEqual(site.breakCount, 0)
    }

    private func limits(
        sites: [String: Int],
        at date: Date,
        active: Bool = true
    ) throws -> DailyLimits {
        var limits = DailyLimits(now: date, calendar: calendar)
        for (domain, minutes) in sites {
            XCTAssertTrue(
                limits.addSite(
                    domain: domain,
                    allowanceMinutes: minutes,
                    at: date,
                    calendar: calendar
                )
            )
        }
        limits.setActive(active, at: date, calendar: calendar)
        return limits
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

private struct LegacyDailyLimits: Encodable {
    let isActive: Bool
    let periodStart: Date
    let sites: [LegacyDailyLimitSite]
}

private struct LegacyDailyLimitSite: Encodable {
    let domain: String
    let allowanceMinutes: Int
    let usedSeconds: TimeInterval
    let blockedSince: Date?
}
