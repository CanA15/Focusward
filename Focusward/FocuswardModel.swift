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
        let bucket = UInt64(max(0, elapsedTime) / 4)
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

    private let store: SessionStore
    private let safari: SafariAutomation
    private var monitorTask: Task<Void, Never>?
    private var earlyEndCountdown: EarlyEndCountdown?
    private var isMainWindowFocused = false
    private var earlyEndDisplaySeed = UInt64.random(in: .min ... .max)

    private init(
        store: SessionStore = SessionStore(),
        safari: SafariAutomation = SafariAutomation()
    ) {
        self.store = store
        self.safari = safari
        self.domains = store.domains

        let preferredDuration = store.preferredDurationMinutes
        if FocusDuration.presets.contains(preferredDuration) {
            self.durationMinutes = preferredDuration
        } else if preferredDuration > 0 {
            let components = FocusDuration.components(totalMinutes: preferredDuration)
            self.usesCustomDuration = true
            self.customHours = components.hours
            self.customMinutes = components.minutes
        }

        let now = Date()
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
            startMonitor()
        } else {
            store.clearSession()
            self.sessionEnd = nil
            self.earlyEndReadyAt = nil
        }
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
        startMonitor()
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

    private func startMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.persistEarlyEndState(at: Date())
                self.enforceCurrentTabs()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func enforceCurrentTabs() {
        guard let end = sessionEnd else { return }
        guard end > Date() else {
            finishSession(message: "Session complete")
            return
        }

        do {
            let snapshots = try safari.tabs()
            var redirects = 0

            for snapshot in snapshots {
                guard
                    let hostname = DomainMatcher.hostname(from: snapshot.url),
                    DomainMatcher.isBlocked(hostname: hostname, by: domains),
                    let destination = shieldURL(sessionEnd: end, hostname: hostname)
                else {
                    continue
                }

                if try safari.redirect(snapshot, to: destination) {
                    redirects += 1
                }
            }

            if redirects > 0 {
                redirectedTabCount += redirects
                automationMessage = "Blocked \(redirects) Safari tab\(redirects == 1 ? "" : "s")"
            } else {
                automationMessage = "Safari monitoring active"
            }
        } catch {
            automationMessage = error.localizedDescription
        }
    }

    private func shieldURL(sessionEnd: Date, hostname: String) -> URL? {
        guard let resource = Bundle.main.url(forResource: "blocked", withExtension: "html") else {
            automationMessage = "Bundled shield page is missing"
            return nil
        }

        var components = URLComponents(url: resource, resolvingAgainstBaseURL: false)
        components?.fragment = "end=\(Int(sessionEnd.timeIntervalSince1970))&host=\(hostname)"
        return components?.url
    }

    private func finishSession(message: String) {
        monitorTask?.cancel()
        monitorTask = nil
        sessionEnd = nil
        earlyEndCountdown = nil
        earlyEndReadyAt = nil
        isEarlyEndTimerRunning = false
        store.clearSession()
        automationMessage = message
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
}
