import Foundation

enum DailyBreakError: LocalizedError {
    case blockedBySession(domain: String)
    case unavailable(domain: String)

    var errorDescription: String? {
        switch self {
        case .blockedBySession(let domain):
            "The focus session blocks \(domain)."
        case .unavailable(let domain):
            "The break for \(domain) cannot start. Check the break time left today."
        }
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
    @Published private(set) var automationMessage = "Ready"
    @Published private(set) var redirectedTabCount = 0
    @Published private(set) var dailyLimits: DailyLimits
    @Published var dailyDraftDomain = ""
    @Published private(set) var dailyDraftAllowanceMinutes = 30
    @Published private(set) var dailyLimitsMessage = "Inactive"
    @Published private(set) var dailyRedirectedTabCount = 0
    @Published private(set) var showsNotchBreakTimer: Bool

    private let store: SessionStore
    private let safari: SafariAutomation
    private var monitorTask: Task<Void, Never>?
    private var lastDailyPersistenceAt: Date?
    private var dailyLimitsNeedPersistence = false

    private init(
        store: SessionStore = SessionStore(),
        safari: SafariAutomation = SafariAutomation()
    ) {
        self.store = store
        self.safari = safari
        self.domains = store.domains
        self.showsNotchBreakTimer = store.showsNotchBreakTimer

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
        } else {
            store.clearSession()
            self.sessionEnd = nil
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

    var canStartSession: Bool {
        !domains.isEmpty && selectedDurationMinutes > 0
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
        if isSessionActive {
            endDailyBreaksBlockedBySession()
        }
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
        redirectedTabCount = 0
        automationMessage = "Starting Safari monitoring…"
        store.sessionEnd = end
        endDailyBreaksBlockedBySession()
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
        if let existing = dailyLimits.overlappingSite(for: normalized) {
            dailyLimitsMessage = existing.domain == normalized
                ? "A daily limit already exists for \(normalized)"
                : "\(normalized) overlaps the rule for \(existing.domain)"
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
        persistDailyLimits()
        updateMonitor()
    }

    func canStartDailyBreak(for domain: String) -> Bool {
        guard
            dailyLimits.isActive,
            let site = dailyLimits.site(for: domain),
            site.activeBreak == nil,
            site.remainingMinutes > 0
        else {
            return false
        }
        return !isBlockedBySession(domain)
    }

    func isBlockedBySession(_ domain: String) -> Bool {
        isSessionActive && domains.contains { DomainMatcher.rulesOverlap($0, domain) }
    }

    func startDailyBreak(for domain: String, minutes: Int) throws {
        guard !isBlockedBySession(domain) else {
            throw DailyBreakError.blockedBySession(domain: domain)
        }
        guard dailyLimits.startBreak(for: domain, minutes: minutes, at: Date()) else {
            throw DailyBreakError.unavailable(domain: domain)
        }
        persistDailyLimits()
    }

    func endDailyBreak(for domain: String) {
        guard dailyLimits.endBreak(for: domain, at: Date()) else { return }
        persistDailyLimits()
    }

    func setShowsNotchBreakTimer(_ shows: Bool) {
        showsNotchBreakTimer = shows
        store.showsNotchBreakTimer = shows
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

    func endSessionEarly() {
        guard isSessionActive else { return }
        finishSession(message: "Session ended early")
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
                self.monitorSafari(at: Date())
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
                    let site = dailyLimits.blockingSite(for: hostname),
                    let reset = dailyLimits.nextReset()
                {
                    destination = shieldURL(
                        blockEnd: reset,
                        hostname: hostname,
                        mode: "daily",
                        breakMinutesLeft: site.remainingMinutes,
                        isBreakBlockedBySession: isBlockedBySession(site.domain)
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

    private func shieldURL(
        blockEnd: Date,
        hostname: String,
        mode: String,
        breakMinutesLeft: Int? = nil,
        isBreakBlockedBySession: Bool = false
    ) -> URL? {
        guard let resource = Bundle.main.url(forResource: "blocked", withExtension: "html") else {
            if mode == "daily" {
                dailyLimitsMessage = "The bundled shield page is missing"
            } else {
                automationMessage = "The bundled shield page is missing"
            }
            return nil
        }

        var components = URLComponents(url: resource, resolvingAgainstBaseURL: false)
        var fragment = "end=\(Int(blockEnd.timeIntervalSince1970))&host=\(hostname)&mode=\(mode)"
        if let breakMinutesLeft {
            fragment += "&left=\(breakMinutesLeft)"
        }
        if isBreakBlockedBySession {
            fragment += "&session=1"
        }
        components?.fragment = fragment
        return components?.url
    }

    private func blockedTabsMessage(count: Int) -> String {
        "Blocked \(count) Safari tab\(count == 1 ? "" : "s")"
    }

    private func finishSession(message: String) {
        sessionEnd = nil
        store.clearSession()
        automationMessage = message
        updateMonitor()
    }

    private func endDailyBreaksBlockedBySession() {
        let previousDailyLimits = dailyLimits
        dailyLimits.endBreaks(overlapping: domains, at: Date())
        if dailyLimits != previousDailyLimits {
            persistDailyLimits()
        }
    }

    private func persistPreferredDuration() {
        guard selectedDurationMinutes > 0 else { return }
        store.preferredDurationMinutes = selectedDurationMinutes
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
