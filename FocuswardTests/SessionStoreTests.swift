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

        let restored = SessionStore(defaults: defaults)
        XCTAssertEqual(restored.domains, ["youtube.com"])
        XCTAssertEqual(restored.preferredDurationMinutes, 270)
        XCTAssertEqual(restored.sessionEnd, end)
        XCTAssertEqual(restored.earlyEndReadyAt, ready)

        restored.clearSession()
        XCTAssertNil(restored.sessionEnd)
        XCTAssertNil(restored.earlyEndReadyAt)
        XCTAssertEqual(restored.domains, ["youtube.com"])
        XCTAssertEqual(restored.preferredDurationMinutes, 270)
    }
}
