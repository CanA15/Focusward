import AppKit
import Foundation

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
    @Published private(set) var automationMessage = "Ready"
    @Published private(set) var redirectedTabCount = 0

    let durationChoices = FocusDuration.presets

    private let store: SessionStore
    private let safari: SafariAutomation
    private var monitorTask: Task<Void, Never>?

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

        if let storedEnd = store.sessionEnd, storedEnd > Date() {
            self.sessionEnd = storedEnd
            self.earlyEndReadyAt = store.earlyEndReadyAt
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

    func removeDomains(at offsets: IndexSet) {
        guard !isSessionActive else { return }
        domains.remove(atOffsets: offsets)
        store.domains = domains
    }

    func removeDomain(_ domain: String) {
        guard !isSessionActive else { return }
        domains.removeAll { $0 == domain }
        store.domains = domains
    }

    func selectDurationPreset(_ minutes: Int) {
        guard durationChoices.contains(minutes) else { return }
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
        earlyEndReadyAt = nil
        redirectedTabCount = 0
        automationMessage = "Starting Safari monitoring…"
        store.sessionEnd = end
        store.earlyEndReadyAt = nil
        startMonitor()
    }

    func requestEarlyEnd() {
        guard isSessionActive, earlyEndReadyAt == nil else { return }
        let readyAt = Date().addingTimeInterval(90)
        earlyEndReadyAt = readyAt
        store.earlyEndReadyAt = readyAt
    }

    func cancelEarlyEnd() {
        earlyEndReadyAt = nil
        store.earlyEndReadyAt = nil
    }

    func confirmEarlyEnd() {
        guard let earlyEndReadyAt, Date() >= earlyEndReadyAt else { return }
        finishSession(message: "Session ended early")
    }

    func checkNow() {
        enforceCurrentTabs()
    }

    private func startMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
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
        earlyEndReadyAt = nil
        store.clearSession()
        automationMessage = message
    }

    private func persistPreferredDuration() {
        guard selectedDurationMinutes > 0 else { return }
        store.preferredDurationMinutes = selectedDurationMinutes
    }
}
