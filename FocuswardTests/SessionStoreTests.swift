import XCTest
@testable import Focusward

final class SessionStoreTests: XCTestCase {
    func testPersistsAndClearsSessionStateLocally() throws {
        let suiteName = "FocuswardTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let end = start.addingTimeInterval(16_200)

        store.domains = ["youtube.com"]
        store.preferredDurationMinutes = 270
        store.sessionStart = start
        store.sessionEnd = end

        let restored = SessionStore(defaults: defaults)
        XCTAssertEqual(restored.domains, ["youtube.com"])
        XCTAssertEqual(restored.preferredDurationMinutes, 270)
        XCTAssertEqual(restored.sessionStart, start)
        XCTAssertEqual(restored.sessionEnd, end)

        restored.clearSession()
        XCTAssertNil(restored.sessionStart)
        XCTAssertNil(restored.sessionEnd)
        XCTAssertEqual(restored.domains, ["youtube.com"])
        XCTAssertEqual(restored.preferredDurationMinutes, 270)
    }

    func testShowsTheNotchBreakTimerUntilTheUserTurnsItOff() throws {
        let suiteName = "FocuswardTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        XCTAssertTrue(store.showsNotchBreakTimer)

        store.showsNotchBreakTimer = false

        XCTAssertFalse(SessionStore(defaults: defaults).showsNotchBreakTimer)
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

    func testApplicationIconIsBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "AppIcon", withExtension: "icns"))
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String, "AppIcon")
    }

    func testShieldPageUsesBundledFocuswardLogo() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "blocked", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)

        XCTAssertNotNil(Bundle.main.url(forResource: "FocuswardLogo", withExtension: "png"))
        XCTAssertTrue(html.contains("<img src=\"FocuswardLogo.png\""))
        XCTAssertTrue(html.contains("img-src 'self'"))
        XCTAssertFalse(html.contains(">F</div>"))
        XCTAssertFalse(html.contains("<svg"))
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

        let store = SessionStore(defaults: defaults)
        store.dailyLimits = limits

        XCTAssertEqual(SessionStore(defaults: defaults).dailyLimits, limits)
    }

    func testShieldPageExplainsDailyLimitBreaks() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "blocked", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(html.contains("params.get(\"mode\")"))
        XCTAssertTrue(html.contains("params.get(\"left\")"))
        XCTAssertTrue(html.contains("Open Focusward to take a break"))
        XCTAssertTrue(html.contains("No break time left today"))
        XCTAssertTrue(html.contains("params.get(\"session\")"))
        XCTAssertTrue(html.contains("You can take a break after the focus session ends."))
        XCTAssertFalse(html.contains("You can open the website"))
    }
}
