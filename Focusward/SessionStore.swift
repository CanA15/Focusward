import Foundation

final class SessionStore {
    private enum Key {
        static let domains = "domains"
        static let preferredDurationMinutes = "preferredDurationMinutes"
        static let sessionEnd = "sessionEnd"
        static let earlyEndReadyAt = "earlyEndReadyAt"
        static let earlyEndRemainingSeconds = "earlyEndRemainingSeconds"
        static let dailyLimits = "dailyLimits"
        static let unreadableDailyLimits = "unreadableDailyLimits"
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

    // An unreadable value moves to a separate key, so that a later save cannot replace the user's data.
    func loadDailyLimits() throws -> DailyLimits? {
        guard let data = defaults.data(forKey: Key.dailyLimits) else { return nil }
        do {
            return try PropertyListDecoder().decode(DailyLimits.self, from: data)
        } catch {
            defaults.set(data, forKey: Key.unreadableDailyLimits)
            defaults.removeObject(forKey: Key.dailyLimits)
            throw error
        }
    }

    func saveDailyLimits(_ dailyLimits: DailyLimits) throws {
        defaults.set(try PropertyListEncoder().encode(dailyLimits), forKey: Key.dailyLimits)
    }

    func clearSession() {
        sessionEnd = nil
        // Earlier versions saved an early-end cooldown. Remove the stale values.
        defaults.removeObject(forKey: Key.earlyEndReadyAt)
        defaults.removeObject(forKey: Key.earlyEndRemainingSeconds)
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
