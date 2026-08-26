import AppKit
import Foundation

struct EarlyEndCountdown {
    static let duration: TimeInterval = 90

    private(set) var elapsed: TimeInterval
    private(set) var resumedAt: Date?

    init(remaining: TimeInterval = duration) {
        elapsed = Self.duration - min(max(remaining, 0), Self.duration)
    }

    var isRunning: Bool { resumedAt != nil }

    mutating func resume(at date: Date) {
        guard resumedAt == nil, !isReady(at: date) else { return }
        resumedAt = date
    }

    mutating func pause(at date: Date) {
        elapsed = elapsedTime(at: date)
        resumedAt = nil
    }

    func elapsedTime(at date: Date) -> TimeInterval {
        min(
            Self.duration,
            elapsed + max(0, resumedAt.map { date.timeIntervalSince($0) } ?? 0)
        )
    }

    func remainingTime(at date: Date) -> TimeInterval {
        max(0, Self.duration - elapsedTime(at: date))
    }

    func isReady(at date: Date) -> Bool {
        remainingTime(at: date) <= 0
    }
}

struct EarlyEndDisplayState {
    static let maximumDisplayedSeconds = 330
    static let updateInterval: TimeInterval = 2
    private static let durationBands = [5 ... 44, 45 ... 89, 90 ... 179, 180 ... 330]

    let displayedSeconds: Int

    var text: String {
        guard displayedSeconds >= 60 else { return "\(displayedSeconds)s" }
        return String(format: "%dm %02ds", displayedSeconds / 60, displayedSeconds % 60)
    }

    var progress: Double {
        1 - Double(displayedSeconds) / Double(Self.maximumDisplayedSeconds)
    }

    static func randomized(elapsedTime: TimeInterval, seed: UInt64) -> Self {
        let bucket = UInt64(max(0, elapsedTime) / updateInterval)
        let firstMix = mix(bucket &+ seed &+ 0x9E3779B97F4A7C15)
        let band = durationBands[Int(firstMix % UInt64(durationBands.count))]
        let seconds = band.lowerBound + Int(mix(firstMix) % UInt64(band.count))
        return Self(displayedSeconds: seconds)
    }

    private static func mix(_ value: UInt64) -> UInt64 {
        var mixed = value
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58476D1CE4E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D049BB133111EB
        return mixed ^ (mixed >> 31)
    }
}

@MainActor
final class FocuswardModel: ObservableObject {
    static let shared = FocuswardModel()

    @Published private(set) var domains: [String]
    @Published var draftDomain = ""
    @Published private(set) var durationMinutes = 45
    @Published private(set) var usesCustomDuration = false
    @Published private(set) var customHours = 4
    @Published private(set) var customMinutes = 0
    @Published private(set) var sessionEnd: Date?
    @Published private(set) var earlyEndReadyAt: Date?
    @Published private(set) var isEarlyEndTimerRunning = false
    @Published private(set) var automationMessage = "Ready"
    @Published private(set) var redirectedTabCount = 0
    @Published private(set) var dailyLimits: DailyLimits
    @Published var dailyDraftDomain = ""
    @Published private(set) var dailyDraftAllowanceMinutes = 30
    @Published private(set) var dailyLimitsMessage = "Inactive"
    @Published private(set) var dailyRedirectedTabCount = 0

    private let store: SessionStore
    private let safari: SafariAutomation
    private var monitorTask: Task<Void, Never>?
    private var earlyEndCountdown: EarlyEndCountdown?
    private var isMainWindowFocused = false
    private var earlyEndDisplaySeed = UInt64.random(in: .min ... .max)
    private var lastDailyUsageSampleAt: Date?
    private var lastDailyPersistenceAt: Date?
    private var dailyLimitsNeedPersistence = false

    private init(
        store: SessionStore = SessionStore(),
        safari: SafariAutomation = SafariAutomation()
    ) {
        self.store = store
        self.safari = safari
        self.domains = store.domains

        let now = Date()
        var restoredDailyLimits = store.dailyLimits ?? DailyLimits(now: now)
        restoredDailyLimits.refresh(at: now)
        self.dailyLimits = restoredDailyLimits
        if restoredDailyLimits.isActive {
            self.dailyLimitsMessage = "Safari monitoring active"
        }

        let preferredDuration = store.preferredDurationMinutes
        if FocusDuration.presets.contains(preferredDuration) {
            self.durationMinutes = preferredDuration
        } else if preferredDuration > 0 {
            let components = FocusDuration.components(totalMinutes: preferredDuration)
            self.usesCustomDuration = true
            self.customHours = components.hours
            self.customMinutes = components.minutes
        }

        if let storedEnd = store.sessionEnd, storedEnd > now {
            self.sessionEnd = storedEnd
            let remaining = store.earlyEndRemainingSeconds
                ?? store.earlyEndReadyAt.map {
                    min(max($0.timeIntervalSince(now), 0), EarlyEndCountdown.duration)
                }
            if let remaining {
                self.earlyEndCountdown = EarlyEndCountdown(remaining: remaining)
                self.earlyEndReadyAt = now.addingTimeInterval(remaining)
            }
        } else {
            store.clearSession()
            self.sessionEnd = nil
            self.earlyEndReadyAt = nil
        }

        updateMonitor()
    }

    var isSessionActive: Bool {
        guard let sessionEnd else { return false }
        return sessionEnd > Date()
    }

    var selectedDurationMinutes: Int {
        usesCustomDuration
            ? FocusDuration.totalMinutes(hours: customHours, minutes: customMinutes)
            : durationMinutes
    }

    var durationSummary: String {
        FocusDuration.label(totalMinutes: selectedDurationMinutes)
    }

    var canStartSession: Bool {
        !domains.isEmpty && selectedDurationMinutes > 0
    }

    var hasEarlyEndRequest: Bool {
        earlyEndCountdown != nil
    }

    var isProtectionActive: Bool {
        isSessionActive || dailyLimits.isActive
    }

    var canActivateDailyLimits: Bool {
        !dailyLimits.sites.isEmpty
    }

    func addDraftDomain() {
        guard let normalized = DomainMatcher.normalizeRule(draftDomain) else {
            automationMessage = "Enter a valid domain such as youtube.com"
            return
        }

        if !domains.contains(normalized) {
            domains.append(normalized)
            domains.sort()
            store.domains = domains
        }
        draftDomain = ""
    }

    func removeDomain(_ domain: String) {
        guard !isSessionActive else { return }
        domains.removeAll { $0 == domain }
        store.domains = domains
    }

    func selectDurationPreset(_ minutes: Int) {
        guard FocusDuration.presets.contains(minutes) else { return }
        durationMinutes = minutes
        usesCustomDuration = false
        store.preferredDurationMinutes = minutes
    }

    func selectCustomDuration() {
        usesCustomDuration = true
        persistPreferredDuration()
    }

    func setCustomHours(_ hours: Int) {
        customHours = min(max(hours, 0), FocusDuration.maximumHours)
        if customHours == FocusDuration.maximumHours {
            customMinutes = 0
        }
        persistPreferredDuration()
    }

    func setCustomMinutes(_ minutes: Int) {
        customMinutes = customHours == FocusDuration.maximumHours
            ? 0
            : min(max(minutes, 0), 59)
        persistPreferredDuration()
    }

    func startSession() {
        guard !domains.isEmpty else {
            automationMessage = "Add at least one domain first"
            return
        }

        guard selectedDurationMinutes > 0 else {
            automationMessage = "Choose a session length first"
            return
        }

        let end = Date().addingTimeInterval(TimeInterval(selectedDurationMinutes * 60))
        sessionEnd = end
        earlyEndCountdown = nil
        earlyEndReadyAt = nil
        isEarlyEndTimerRunning = false
        redirectedTabCount = 0
        automationMessage = "Starting Safari monitoring…"
        store.sessionEnd = end
        store.earlyEndReadyAt = nil
        store.earlyEndRemainingSeconds = nil
        updateMonitor()
    }

    func setDailyDraftAllowanceMinutes(_ minutes: Int) {
        guard !dailyLimits.isActive else { return }
        dailyDraftAllowanceMinutes = min(
            max(minutes, DailyLimits.allowanceRange.lowerBound),
            DailyLimits.allowanceRange.upperBound
        )
    }

    func addDailyDraftSite() {
        guard !dailyLimits.isActive else { return }
        guard let normalized = DomainMatcher.normalizeRule(dailyDraftDomain) else {
            dailyLimitsMessage = "Enter a valid domain such as youtube.com"
            return
        }
        guard dailyLimits.site(for: normalized) == nil else {
            dailyLimitsMessage = "A daily limit already exists for \(normalized)"
            return
        }

        guard dailyLimits.addSite(
            domain: normalized,
            allowanceMinutes: dailyDraftAllowanceMinutes,
            at: Date()
        ) else {
            return
        }

        dailyDraftDomain = ""
        dailyLimitsMessage = "Added \(normalized)"
        persistDailyLimits()
    }

    func updateDailyAllowance(for domain: String, minutes: Int) {
        refreshDailyLimits()
        guard dailyLimits.updateAllowance(for: domain, minutes: minutes) else { return }
        dailyLimitsMessage = "Updated \(domain)"
        persistDailyLimits()
    }

    func removeDailyLimit(for domain: String) {
        guard dailyLimits.removeSite(domain: domain) else { return }
        dailyLimitsMessage = "Removed \(domain)"
        persistDailyLimits()
    }

    func setDailyLimitsActive(_ active: Bool) {
        guard active != dailyLimits.isActive else { return }
        if active, dailyLimits.sites.isEmpty {
            dailyLimitsMessage = "Add at least one website first"
            return
        }

        let now = Date()
        dailyLimits.setActive(active, at: now)
        dailyRedirectedTabCount = 0
        dailyLimitsMessage = active ? "Starting Safari monitoring…" : "Inactive"
        lastDailyUsageSampleAt = nil
        persistDailyLimits()
        updateMonitor()
    }

    func persistStateForTermination() {
        persistDailyLimits()
    }

    func refreshDailyLimits(at date: Date = Date()) {
        let previousDailyLimits = dailyLimits
        dailyLimits.refresh(at: date)
        if dailyLimits != previousDailyLimits {
            persistDailyLimits(at: date)
        }
    }

    func requestEarlyEnd() {
        guard isSessionActive, earlyEndCountdown == nil else { return }
        let now = Date()
        var countdown = EarlyEndCountdown()
        if isMainWindowFocused {
            countdown.resume(at: now)
        }
        earlyEndCountdown = countdown
        earlyEndDisplaySeed = UInt64.random(in: .min ... .max)
        isEarlyEndTimerRunning = countdown.isRunning
        persistEarlyEndState(at: now, updateProjection: true)
    }

    func cancelEarlyEnd() {
        earlyEndCountdown = nil
        earlyEndReadyAt = nil
        isEarlyEndTimerRunning = false
        store.earlyEndReadyAt = nil
        store.earlyEndRemainingSeconds = nil
    }

    func confirmEarlyEnd() {
        guard earlyEndCountdown?.isReady(at: Date()) == true else { return }
        finishSession(message: "Session ended early")
    }

    func setMainWindowFocused(_ focused: Bool) {
        guard focused != isMainWindowFocused else { return }
        let now = Date()

        if focused {
            earlyEndCountdown?.resume(at: now)
        } else {
            earlyEndCountdown?.pause(at: now)
        }

        isMainWindowFocused = focused
        isEarlyEndTimerRunning = earlyEndCountdown?.isRunning == true
        persistEarlyEndState(at: now, updateProjection: true)
    }

    func earlyEndIsReady(at date: Date) -> Bool {
        earlyEndCountdown?.isReady(at: date) == true
    }

    func earlyEndDisplay(at date: Date) -> EarlyEndDisplayState {
        EarlyEndDisplayState.randomized(
            elapsedTime: earlyEndCountdown?.elapsedTime(at: date) ?? 0,
            seed: earlyEndDisplaySeed
        )
    }

    private func updateMonitor() {
        let needsMonitor = sessionEnd != nil || dailyLimits.isActive
        guard needsMonitor else {
            monitorTask?.cancel()
            monitorTask = nil
            return
        }
        guard monitorTask == nil else { return }

        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = Date()
                self.persistEarlyEndState(at: now)
                self.monitorSafari(at: now)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func monitorSafari(at date: Date) {
        var activeSessionEnd: Date?
        if let end = sessionEnd, end <= date {
            finishSession(message: "Session complete")
        } else {
            activeSessionEnd = sessionEnd
        }

        guard activeSessionEnd != nil || dailyLimits.isActive else { return }

        let previousDailyLimits = dailyLimits
        dailyLimits.refresh(at: date)
        if dailyLimits != previousDailyLimits {
            dailyLimitsNeedPersistence = true
        }

        do {
            let snapshots = try safari.tabs()
            recordDailyUsage(from: snapshots, sessionEnd: activeSessionEnd, at: date)

            var sessionRedirects = 0
            var dailyRedirects = 0

            for snapshot in snapshots {
                guard let hostname = DomainMatcher.hostname(from: snapshot.url) else { continue }

                let destination: URL?
                let isSessionBlock = activeSessionEnd != nil
                    && DomainMatcher.isBlocked(hostname: hostname, by: domains)

                if isSessionBlock, let activeSessionEnd {
                    destination = shieldURL(
                        blockEnd: activeSessionEnd,
                        hostname: hostname,
                        mode: "session"
                    )
                } else if
                    dailyLimits.blockingSite(for: hostname) != nil,
                    let reset = dailyLimits.nextReset()
                {
                    destination = shieldURL(
                        blockEnd: reset,
                        hostname: hostname,
                        mode: "daily"
                    )
                } else {
                    destination = nil
                }

                guard let destination else { continue }
                if try safari.redirect(snapshot, to: destination) {
                    if isSessionBlock {
                        sessionRedirects += 1
                    } else {
                        dailyRedirects += 1
                    }
                }
            }

            if activeSessionEnd != nil {
                redirectedTabCount += sessionRedirects
                automationMessage = sessionRedirects > 0
                    ? blockedTabsMessage(count: sessionRedirects)
                    : "Safari monitoring active"
            }
            if dailyLimits.isActive {
                dailyRedirectedTabCount += dailyRedirects
                dailyLimitsMessage = dailyRedirects > 0
                    ? blockedTabsMessage(count: dailyRedirects)
                    : "Safari monitoring active"
            }
        } catch {
            if activeSessionEnd != nil {
                automationMessage = error.localizedDescription
            }
            if dailyLimits.isActive {
                dailyLimitsMessage = error.localizedDescription
            }
        }

        persistDailyLimitsIfNeeded(at: date)
    }

    private func recordDailyUsage(
        from snapshots: [SafariTabSnapshot],
        sessionEnd: Date?,
        at date: Date
    ) {
        guard dailyLimits.isActive else { return }

        let duration = min(
            max(date.timeIntervalSince(lastDailyUsageSampleAt ?? date), 0),
            1
        )
        lastDailyUsageSampleAt = date

        let activeHostname = snapshots
            .first(where: \.isActive)
            .flatMap { DomainMatcher.hostname(from: $0.url) }
        let isBlockedBySession = sessionEnd != nil
            && activeHostname.map { DomainMatcher.isBlocked(hostname: $0, by: domains) } == true
        let hostname = isBlockedBySession ? nil : activeHostname
        let previousDailyLimits = dailyLimits

        dailyLimits.recordUsage(
            hostname: hostname,
            duration: duration,
            at: date
        )
        if dailyLimits != previousDailyLimits {
            dailyLimitsNeedPersistence = true
        }
    }

    private func shieldURL(blockEnd: Date, hostname: String, mode: String) -> URL? {
        guard let resource = Bundle.main.url(forResource: "blocked", withExtension: "html") else {
            if mode == "daily" {
                dailyLimitsMessage = "The bundled shield page is missing"
            } else {
                automationMessage = "The bundled shield page is missing"
            }
            return nil
        }

        var components = URLComponents(url: resource, resolvingAgainstBaseURL: false)
        components?.fragment = "end=\(Int(blockEnd.timeIntervalSince1970))&host=\(hostname)&mode=\(mode)"
        return components?.url
    }

    private func blockedTabsMessage(count: Int) -> String {
        "Blocked \(count) Safari tab\(count == 1 ? "" : "s")"
    }

    private func finishSession(message: String) {
        sessionEnd = nil
        earlyEndCountdown = nil
        earlyEndReadyAt = nil
        isEarlyEndTimerRunning = false
        store.clearSession()
        automationMessage = message
        updateMonitor()
    }

    private func persistPreferredDuration() {
        guard selectedDurationMinutes > 0 else { return }
        store.preferredDurationMinutes = selectedDurationMinutes
    }

    private func persistEarlyEndState(at date: Date, updateProjection: Bool = false) {
        guard let countdown = earlyEndCountdown else { return }
        let remaining = countdown.remainingTime(at: date)
        let projectedReadyAt = date.addingTimeInterval(remaining)
        store.earlyEndRemainingSeconds = remaining
        store.earlyEndReadyAt = projectedReadyAt
        if updateProjection {
            earlyEndReadyAt = projectedReadyAt
        }
    }

    private func persistDailyLimitsIfNeeded(at date: Date) {
        guard dailyLimitsNeedPersistence else { return }
        guard date.timeIntervalSince(lastDailyPersistenceAt ?? .distantPast) >= 5 else {
            return
        }
        persistDailyLimits(at: date)
    }

    private func persistDailyLimits(at date: Date = Date()) {
        store.dailyLimits = dailyLimits
        dailyLimitsNeedPersistence = false
        lastDailyPersistenceAt = date
    }
}
