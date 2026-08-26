import Foundation

struct DailyLimitSite: Codable, Equatable, Identifiable {
    let domain: String
    var allowanceMinutes: Int
    private(set) var usedSeconds: TimeInterval
    private(set) var blockedSince: Date?

    var id: String { domain }

    var allowanceSeconds: TimeInterval {
        TimeInterval(allowanceMinutes * 60)
    }

    var remainingSeconds: TimeInterval {
        max(0, allowanceSeconds - usedSeconds)
    }

    var isExhausted: Bool {
        remainingSeconds <= 0
    }

    init(
        domain: String,
        allowanceMinutes: Int,
        usedSeconds: TimeInterval = 0,
        blockedSince: Date? = nil
    ) {
        self.domain = domain
        self.allowanceMinutes = allowanceMinutes
        self.usedSeconds = max(0, usedSeconds)
        self.blockedSince = blockedSince
    }

    mutating func recordUsage(_ duration: TimeInterval, at date: Date) {
        guard duration.isFinite, duration > 0, !isExhausted else { return }
        usedSeconds += min(duration, remainingSeconds)
        if isExhausted {
            blockedSince = date
        }
    }

    mutating func resetUsage() {
        usedSeconds = 0
        blockedSince = nil
    }

    mutating func setBlocked(_ blocked: Bool, at date: Date) {
        blockedSince = blocked && isExhausted ? blockedSince ?? date : nil
    }
}

struct DailyLimits: Codable, Equatable {
    static let allowanceRange = 1 ... 1_440

    private(set) var isActive: Bool
    private(set) var periodStart: Date
    private(set) var sites: [DailyLimitSite]

    init(now: Date, calendar: Calendar = .current) {
        isActive = false
        periodStart = calendar.startOfDay(for: now)
        sites = []
    }

    mutating func setActive(
        _ active: Bool,
        at date: Date,
        calendar: Calendar = .current
    ) {
        refresh(at: date, calendar: calendar)
        isActive = active
        for index in sites.indices {
            sites[index].setBlocked(active, at: date)
        }
    }

    @discardableResult
    mutating func addSite(
        domain: String,
        allowanceMinutes: Int,
        at date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard !isActive else { return false }
        guard let normalized = DomainMatcher.normalizeRule(domain) else { return false }
        guard !sites.contains(where: { $0.domain == normalized }) else { return false }

        refresh(at: date, calendar: calendar)
        sites.append(
            DailyLimitSite(
                domain: normalized,
                allowanceMinutes: Self.clampedAllowance(allowanceMinutes)
            )
        )
        sites.sort { $0.domain < $1.domain }
        return true
    }

    @discardableResult
    mutating func updateAllowance(for domain: String, minutes: Int) -> Bool {
        guard !isActive else { return false }
        guard let index = sites.firstIndex(where: { $0.domain == domain }) else {
            return false
        }

        sites[index].allowanceMinutes = Self.clampedAllowance(minutes)
        return true
    }

    @discardableResult
    mutating func removeSite(domain: String) -> Bool {
        guard !isActive else { return false }
        guard let index = sites.firstIndex(where: { $0.domain == domain }) else {
            return false
        }

        sites.remove(at: index)
        return true
    }

    mutating func recordUsage(
        hostname: String?,
        duration: TimeInterval,
        at date: Date,
        calendar: Calendar = .current
    ) {
        refresh(at: date, calendar: calendar)
        guard isActive, let hostname else { return }
        guard let index = sites.firstIndex(where: {
            DomainMatcher.isBlocked(hostname: hostname, by: [$0.domain])
        }) else {
            return
        }

        sites[index].recordUsage(duration, at: date)
    }

    mutating func refresh(at date: Date, calendar: Calendar = .current) {
        let currentPeriodStart = calendar.startOfDay(for: date)
        guard currentPeriodStart != periodStart else { return }

        periodStart = currentPeriodStart
        for index in sites.indices {
            sites[index].resetUsage()
        }
    }

    func site(for domain: String) -> DailyLimitSite? {
        sites.first { $0.domain == domain }
    }

    func matchingSite(for hostname: String) -> DailyLimitSite? {
        sites.first {
            DomainMatcher.isBlocked(hostname: hostname, by: [$0.domain])
        }
    }

    func blockingSite(for hostname: String) -> DailyLimitSite? {
        guard isActive else { return nil }
        return matchingSite(for: hostname).flatMap { $0.isExhausted ? $0 : nil }
    }

    func nextReset(calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: periodStart)
    }

    private static func clampedAllowance(_ minutes: Int) -> Int {
        min(max(minutes, allowanceRange.lowerBound), allowanceRange.upperBound)
    }
}
