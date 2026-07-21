import AppKit
import Foundation

@MainActor
final class FocuswardModel: ObservableObject {
    static let shared = FocuswardModel()

    @Published private(set) var domains: [String]
    @Published var draftDomain = ""
    @Published var durationMinutes = 45
    @Published private(set) var sessionEnd: Date?
    @Published private(set) var earlyEndReadyAt: Date?
    @Published private(set) var automationMessage = "Ready"
    @Published private(set) var redirectedTabCount = 0

    let durationChoices = [15, 25, 45, 60, 90, 120]

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

    func startSession() {
        guard !domains.isEmpty else {
            automationMessage = "Add at least one domain first"
            return
        }

        let end = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
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
}
