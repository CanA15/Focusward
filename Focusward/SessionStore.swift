import Foundation

final class SessionStore {
    private enum Key {
        static let domains = "domains"
        static let preferredDurationMinutes = "preferredDurationMinutes"
        static let sessionEnd = "sessionEnd"
        static let earlyEndReadyAt = "earlyEndReadyAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var domains: [String] {
        get { defaults.stringArray(forKey: Key.domains) ?? [] }
        set { defaults.set(newValue, forKey: Key.domains) }
    }

    var sessionEnd: Date? {
        get { date(forKey: Key.sessionEnd) }
        set { set(newValue, forKey: Key.sessionEnd) }
    }

    var preferredDurationMinutes: Int {
        get {
            let stored = defaults.integer(forKey: Key.preferredDurationMinutes)
            return stored > 0 ? stored : 45
        }
        set {
            defaults.set(
                min(max(newValue, 1), FocusDuration.maximumHours * 60),
                forKey: Key.preferredDurationMinutes
            )
        }
    }

    var earlyEndReadyAt: Date? {
        get { date(forKey: Key.earlyEndReadyAt) }
        set { set(newValue, forKey: Key.earlyEndReadyAt) }
    }

    func clearSession() {
        sessionEnd = nil
        earlyEndReadyAt = nil
    }

    private func date(forKey key: String) -> Date? {
        let timestamp = defaults.double(forKey: key)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    private func set(_ date: Date?, forKey key: String) {
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
