import XCTest
@testable import Focusward

final class SessionStoreTests: XCTestCase {
    func testPersistsAndClearsSessionStateLocally() throws {
        let suiteName = "FocuswardTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SessionStore(defaults: defaults)
        let end = Date(timeIntervalSince1970: 2_000_000_000)
        let ready = end.addingTimeInterval(-90)

        store.domains = ["youtube.com"]
        store.preferredDurationMinutes = 270
        store.sessionEnd = end
        store.earlyEndReadyAt = ready
        store.earlyEndRemainingSeconds = 42

        let restored = SessionStore(defaults: defaults)
        XCTAssertEqual(restored.domains, ["youtube.com"])
        XCTAssertEqual(restored.preferredDurationMinutes, 270)
        XCTAssertEqual(restored.sessionEnd, end)
        XCTAssertEqual(restored.earlyEndReadyAt, ready)
        XCTAssertEqual(restored.earlyEndRemainingSeconds, 42)

        restored.clearSession()
        XCTAssertNil(restored.sessionEnd)
        XCTAssertNil(restored.earlyEndReadyAt)
        XCTAssertNil(restored.earlyEndRemainingSeconds)
        XCTAssertEqual(restored.domains, ["youtube.com"])
        XCTAssertEqual(restored.preferredDurationMinutes, 270)
    }

    func testEarlyEndCountdownAdvancesOnlyWhileResumed() {
        let start = Date(timeIntervalSince1970: 1_000)
        var countdown = EarlyEndCountdown()

        countdown.resume(at: start)
        XCTAssertEqual(countdown.remainingTime(at: start.addingTimeInterval(30)), 60)

        countdown.pause(at: start.addingTimeInterval(30))
        XCTAssertEqual(countdown.remainingTime(at: start.addingTimeInterval(300)), 60)
        XCTAssertFalse(countdown.isReady(at: start.addingTimeInterval(300)))

        countdown.resume(at: start.addingTimeInterval(300))
        XCTAssertTrue(countdown.isReady(at: start.addingTimeInterval(360)))
    }
}
