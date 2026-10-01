import XCTest
@testable import Focusward

final class SessionStoreTests: XCTestCase {
    func testPersistsAndClearsSessionStateLocally() throws {
        let suiteName = "FocuswardTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let end = Date(timeIntervalSince1970: 2_000_000_000)

        store.domains = ["youtube.com"]
        store.preferredDurationMinutes = 270
        store.sessionEnd = end

        let restored = SessionStore(defaults: defaults)
        XCTAssertEqual(restored.domains, ["youtube.com"])
        XCTAssertEqual(restored.preferredDurationMinutes, 270)
        XCTAssertEqual(restored.sessionEnd, end)

        restored.clearSession()
        XCTAssertNil(restored.sessionEnd)
        XCTAssertEqual(restored.domains, ["youtube.com"])
        XCTAssertEqual(restored.preferredDurationMinutes, 270)
    }

    func testClearingASessionRemovesTheSavedEarlyEndCooldown() throws {
        let suiteName = "FocuswardTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(2_000_000_000.0, forKey: "earlyEndReadyAt")
        defaults.set(42.0, forKey: "earlyEndRemainingSeconds")

        SessionStore(defaults: defaults).clearSession()

        XCTAssertNil(defaults.object(forKey: "earlyEndReadyAt"))
        XCTAssertNil(defaults.object(forKey: "earlyEndRemainingSeconds"))
    }

    func testPersistsDailyLimitsLocally() throws {
        let suiteName = "FocuswardTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date(timeIntervalSince1970: 2_000_000_000)
        var limits = DailyLimits(now: start)
        XCTAssertTrue(
            limits.addSite(
                domain: "youtube.com",
                allowanceMinutes: 30,
                at: start
            )
        )
        limits.setActive(true, at: start)
        XCTAssertTrue(limits.startBreak(for: "youtube.com", minutes: 5, at: start))

        try SessionStore(defaults: defaults).saveDailyLimits(limits)

        XCTAssertEqual(try SessionStore(defaults: defaults).loadDailyLimits(), limits)
    }

    func testMovesUnreadableDailyLimitsToASeparateKey() throws {
        let suiteName = "FocuswardTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let unreadable = Data("not a property list".utf8)
        defaults.set(unreadable, forKey: "dailyLimits")
        let store = SessionStore(defaults: defaults)

        XCTAssertThrowsError(try store.loadDailyLimits())
        XCTAssertNil(try store.loadDailyLimits())

        try store.saveDailyLimits(DailyLimits(now: Date(timeIntervalSince1970: 2_000_000_000)))
        XCTAssertEqual(defaults.data(forKey: "unreadableDailyLimits"), unreadable)
    }
}
