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

    func testAWebsiteAddedDuringASessionIsBlockedAndEndsItsBreak() async throws {
        let safari = FakeSafari(urls: ["https://youtube.com/", "https://reddit.com/"])
        let model = try makeModel(safari: safari)
        model.dailyDraftDomain = "youtube.com"
        model.addDailyDraftSite()
        model.setDailyLimitsActive(true)
        try model.startDailyBreak(for: "youtube.com", minutes: 5)
        model.draftDomain = "reddit.com"
        model.addDraftDomain()
        model.startSession()

        model.draftDomain = "youtube.com"
        model.addDraftDomain()
        await model.monitorSafari(at: Date())

        XCTAssertEqual(model.domains, ["reddit.com", "youtube.com"])
        XCTAssertNil(model.dailyLimits.site(for: "youtube.com")?.activeBreak)
        let redirects = await safari.redirects
        XCTAssertEqual(redirects.map(\.tabURL), ["https://youtube.com/", "https://reddit.com/"])
        XCTAssertEqual(model.redirectedTabCount, 2)
    }

    func testReportsTheWholeSecondsLeftInTheSession() throws {
        let model = try makeModel(safari: FakeSafari(urls: []))
        XCTAssertEqual(model.sessionSecondsLeft(at: Date()), 0)

        model.draftDomain = "youtube.com"
        model.addDraftDomain()
        model.selectDurationPreset(25)
        model.startSession()
        let end = try XCTUnwrap(model.sessionEnd)

        XCTAssertEqual(model.sessionSecondsLeft(at: end.addingTimeInterval(-90.5)), 90)
        XCTAssertEqual(model.sessionSecondsLeft(at: end.addingTimeInterval(10)), 0)
    }

    func testTheSessionMessageHasPriorityInTheProtectionStatus() async throws {
        let model = try makeModel(safari: FakeSafari(urls: ["https://reddit.com/"]))
        model.draftDomain = "reddit.com"
        model.addDraftDomain()
        model.dailyDraftDomain = "youtube.com"
        model.addDailyDraftSite()
        XCTAssertEqual(model.protectionStatusMessage, "Ready")

        model.setDailyLimitsActive(true)
        XCTAssertEqual(model.protectionStatusMessage, "Starting Safari monitoring…")

        model.startSession()
        await model.monitorSafari(at: Date())
        XCTAssertEqual(model.dailyLimitsMessage, "Safari monitoring active")
        XCTAssertEqual(model.protectionStatusMessage, "Blocked 1 Safari tab")
    }

    func testIgnoresRequestsThatTheControlsDoNotAllow() throws {
        let model = try makeModel(safari: FakeSafari(urls: []))

        model.draftDomain = "not a domain"
        model.addDraftDomain()
        model.startSession()
        model.dailyDraftDomain = "not a domain"
        model.addDailyDraftSite()
        model.setDailyLimitsActive(true)

        XCTAssertEqual(model.domains, [])
        XCTAssertFalse(model.isSessionActive)
        XCTAssertEqual(model.dailyLimits.sites, [])
        XCTAssertFalse(model.dailyLimits.isActive)
    }

    func testKeepsUnreadableDailyLimitsAndReportsTheError() throws {
        let defaults = try makeDefaults()
        let unreadable = Data("not a property list".utf8)
        defaults.set(unreadable, forKey: "dailyLimits")

        let model = makeModel(safari: FakeSafari(urls: []), store: SessionStore(defaults: defaults))
        XCTAssertEqual(model.dailyLimitsMessage, "Focusward could not read the saved Daily Limits. It kept a copy of the data.")

        model.dailyDraftDomain = "youtube.com"
        model.addDailyDraftSite()

        XCTAssertEqual(defaults.data(forKey: "unreadableDailyLimits"), unreadable)
        XCTAssertEqual(try SessionStore(defaults: defaults).loadDailyLimits()?.sites.map(\.domain), ["youtube.com"])
    }

    func testSavesABreakThatEndedWhileFocuswardWasNotRunning() throws {
        let store = try makeStore()
        let breakStart = Date().addingTimeInterval(-30 * 60)
        var limits = DailyLimits(now: breakStart)
        limits.addSite(domain: "youtube.com", allowanceMinutes: 30, at: breakStart)
        limits.setActive(true, at: breakStart)
        limits.startBreak(for: "youtube.com", minutes: 5, at: breakStart)
        try store.saveDailyLimits(limits)

        _ = makeModel(safari: FakeSafari(urls: []), store: store)

        XCTAssertNil(try store.loadDailyLimits()?.site(for: "youtube.com")?.activeBreak)
    }

    func testSavesABreakThatEndsDuringMonitoring() async throws {
        let store = try makeStore()
        let model = makeModel(safari: FakeSafari(urls: []), store: store)
        model.dailyDraftDomain = "youtube.com"
        model.addDailyDraftSite()
        model.setDailyLimitsActive(true)
        try model.startDailyBreak(for: "youtube.com", minutes: 5)

        await model.monitorSafari(at: Date().addingTimeInterval(6 * 60))

        XCTAssertNil(try store.loadDailyLimits()?.site(for: "youtube.com")?.activeBreak)
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
