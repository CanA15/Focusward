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

    func testEarlyEndDisplayBalancesShortAndLongEstimates() {
        let states = (0 ..< 400).map {
            EarlyEndDisplayState.randomized(
                elapsedTime: TimeInterval($0) * EarlyEndDisplayState.updateInterval,
                seed: 42
            )
        }

        XCTAssertGreaterThan(states.count { $0.displayedSeconds < 60 }, 70)
        XCTAssertGreaterThan(states.count { $0.displayedSeconds >= 180 }, 70)
        XCTAssertTrue(states.allSatisfy { (5 ... 330).contains($0.displayedSeconds) })
    }

    func testEarlyEndDisplayProgressMatchesItsLabel() {
        let short = EarlyEndDisplayState(displayedSeconds: 15)
        let long = EarlyEndDisplayState(displayedSeconds: 240)

        XCTAssertEqual(short.text, "15s")
        XCTAssertEqual(long.text, "4m 00s")
        XCTAssertEqual(short.progress, 1 - 15.0 / 330.0, accuracy: 0.000_001)
        XCTAssertEqual(long.progress, 1 - 240.0 / 330.0, accuracy: 0.000_001)
        XCTAssertGreaterThan(short.progress, long.progress)
    }

    func testApplicationIconIsBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "AppIcon", withExtension: "icns"))
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String, "AppIcon")
    }
}
