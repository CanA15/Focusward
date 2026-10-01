import XCTest
@testable import Focusward

@MainActor
final class FocuswardModelTests: XCTestCase {
    func testSessionRedirectsOnlyTheBlockedTabs() async throws {
        let safari = FakeSafari(urls: ["https://www.youtube.com/watch?v=1", "https://example.com/"])
        let model = try makeModel(safari: safari)
        model.draftDomain = "youtube.com"
        model.addDraftDomain()
        model.startSession()

        await model.monitorSafari(at: Date())

        let redirects = await safari.redirects
        XCTAssertEqual(redirects.map(\.tabURL), ["https://www.youtube.com/watch?v=1"])
        XCTAssertTrue(try XCTUnwrap(redirects.first?.destination.fragment).contains("mode=session"))
        XCTAssertEqual(model.redirectedTabCount, 1)
        XCTAssertEqual(model.automationMessage, "Blocked 1 Safari tab")
    }

    func testDailyLimitsRedirectTheBlockedTabs() async throws {
        let safari = FakeSafari(urls: ["https://m.youtube.com/", "https://example.com/"])
        let model = try makeModel(safari: safari)
        model.dailyDraftDomain = "youtube.com"
        model.addDailyDraftSite()
        model.setDailyLimitsActive(true)

        await model.monitorSafari(at: Date())

        let redirects = await safari.redirects
        XCTAssertEqual(redirects.map(\.tabURL), ["https://m.youtube.com/"])
        XCTAssertTrue(try XCTUnwrap(redirects.first?.destination.fragment).contains("mode=daily"))
        XCTAssertEqual(model.dailyRedirectedTabCount, 1)
    }

    func testEndingTheSessionDuringAScanStopsTheRemainingRedirects() async throws {
        let safari = FakeSafari(urls: ["https://youtube.com/1", "https://youtube.com/2"])
        let model = try makeModel(safari: safari)
        model.draftDomain = "youtube.com"
        model.addDraftDomain()
        model.startSession()
        await safari.setOnRedirect { model.endSessionEarly() }

        await model.monitorSafari(at: Date())

        let redirects = await safari.redirects
        XCTAssertEqual(redirects.map(\.tabURL), ["https://youtube.com/1"])
        XCTAssertFalse(model.isSessionActive)
        XCTAssertEqual(model.automationMessage, "Session ended early")
    }

    private func makeModel(safari: FakeSafari) throws -> FocuswardModel {
        try makeModel(safari: safari, store: makeStore())
    }

    private func makeModel(safari: FakeSafari, store: SessionStore) -> FocuswardModel {
        FocuswardModel(store: store, safari: safari, monitorsSafariAutomatically: false)
    }

    private func makeStore() throws -> SessionStore {
        try SessionStore(defaults: makeDefaults())
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "FocuswardTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        return try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }
}

private actor FakeSafari: SafariTabAutomation {
    struct Redirect: Sendable {
        let tabURL: String
        let destination: URL
    }

    private let openTabs: [SafariTabSnapshot]
    private(set) var redirects: [Redirect] = []
    private var onRedirect: (@MainActor @Sendable () -> Void)?

    init(urls: [String]) {
        openTabs = urls.enumerated().map { index, url in
            SafariTabSnapshot(windowIndex: 1, tabIndex: index + 1, url: url)
        }
    }

    func tabs() -> [SafariTabSnapshot] {
        openTabs
    }

    func setOnRedirect(_ action: @escaping @MainActor @Sendable () -> Void) {
        onRedirect = action
    }

    func redirect(_ tab: SafariTabSnapshot, to destination: URL) async -> Bool {
        redirects.append(Redirect(tabURL: tab.url, destination: destination))
        await onRedirect?()
        return true
    }
}
