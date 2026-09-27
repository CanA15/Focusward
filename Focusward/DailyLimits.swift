import Foundation

struct DailyBreak: Codable, Equatable {
    let start: Date
    let end: Date
}

struct DailyLimitSite: Codable, Equatable, Identifiable {
    let domain: String
    var allowanceMinutes: Int
    private(set) var usedSeconds: TimeInterval
    private(set) var activeBreak: DailyBreak?
    private(set) var breakCount: Int

    var id: String { domain }

    var allowanceSeconds: TimeInterval {
        TimeInterval(allowanceMinutes * 60)
    }

    // A running break reserves its full length when it starts.
    var remainingSeconds: TimeInterval {
        max(0, allowanceSeconds - usedSeconds)
    }

    var remainingMinutes: Int {
        Int(remainingSeconds / 60)
    }

    init(domain: String, allowanceMinutes: Int) {
        self.domain = domain
        self.allowanceMinutes = allowanceMinutes
        usedSeconds = 0
        activeBreak = nil
        breakCount = 0
    }

    // Daily limits saved before breaks existed have no break fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        domain = try container.decode(String.self, forKey: .domain)
        allowanceMinutes = try container.decode(Int.self, forKey: .allowanceMinutes)
        usedSeconds = max(0, try container.decode(TimeInterval.self, forKey: .usedSeconds))
        activeBreak = try container.decodeIfPresent(DailyBreak.self, forKey: .activeBreak)
        breakCount = try container.decodeIfPresent(Int.self, forKey: .breakCount) ?? 0
    }

    func isOnBreak(at date: Date) -> Bool {
        activeBreak.map { date < $0.end } ?? false
    }

    mutating func startBreak(minutes: Int, at date: Date) -> Bool {
        let length = TimeInterval(minutes * 60)
        guard activeBreak == nil, minutes > 0, length <= remainingSeconds else {
            return false
        }

        activeBreak = DailyBreak(start: date, end: date.addingTimeInterval(length))
        usedSeconds += length
        breakCount += 1
        return true
    }

    // An early end charges the time used, rounded up to whole minutes.
    mutating func endBreak(at date: Date) {
        guard let activeBreak else { return }
        let length = activeBreak.end.timeIntervalSince(activeBreak.start)
        let elapsed = min(max(date.timeIntervalSince(activeBreak.start), 0), length)
        let charged = (elapsed / 60).rounded(.up) * 60
        usedSeconds -= length - min(charged, length)
        self.activeBreak = nil
    }

    mutating func expireBreak(at date: Date) {
        guard let activeBreak, date >= activeBreak.end else { return }
        self.activeBreak = nil
    }

    mutating func resetDay() {
        usedSeconds = 0
        activeBreak = nil
        breakCount = 0
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
        guard !active else { return }
        for index in sites.indices {
            sites[index].endBreak(at: date)
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

    @discardableResult
    mutating func startBreak(
        for domain: String,
        minutes: Int,
        at date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        refresh(at: date, calendar: calendar)
        guard isActive, let index = sites.firstIndex(where: { $0.domain == domain }) else {
            return false
        }

        return sites[index].startBreak(minutes: minutes, at: date)
    }

    @discardableResult
    mutating func endBreak(
        for domain: String,
        at date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        refresh(at: date, calendar: calendar)
        guard
            let index = sites.firstIndex(where: { $0.domain == domain }),
            sites[index].activeBreak != nil
        else {
            return false
        }

        sites[index].endBreak(at: date)
        return true
    }

    mutating func endBreaks(
        blockedBy rules: [String],
        at date: Date,
        calendar: Calendar = .current
    ) {
        refresh(at: date, calendar: calendar)
        for index in sites.indices
        where DomainMatcher.isBlocked(hostname: sites[index].domain, by: rules) {
            sites[index].endBreak(at: date)
        }
    }

    mutating func refresh(at date: Date, calendar: Calendar = .current) {
        let currentPeriodStart = calendar.startOfDay(for: date)
        guard currentPeriodStart != periodStart else {
            for index in sites.indices {
                sites[index].expireBreak(at: date)
            }
            return
        }

        periodStart = currentPeriodStart
        for index in sites.indices {
            sites[index].resetDay()
        }
    }

    func site(for domain: String) -> DailyLimitSite? {
        sites.first { $0.domain == domain }
    }

    func blockingSite(for hostname: String, at date: Date) -> DailyLimitSite? {
        guard isActive else { return nil }
        return sites.first {
            DomainMatcher.isBlocked(hostname: hostname, by: [$0.domain]) && !$0.isOnBreak(at: date)
        }
    }

    func nextReset(calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .day, value: 1, to: periodStart)
    }

    private static func clampedAllowance(_ minutes: Int) -> Int {
        min(max(minutes, allowanceRange.lowerBound), allowanceRange.upperBound)
    }
}
