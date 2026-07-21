enum FocusDuration {
    static let presets = [25, 45, 60, 120, 240]
    static let maximumHours = 720

    static func totalMinutes(hours: Int, minutes: Int) -> Int {
        let safeHours = min(max(hours, 0), maximumHours)
        let safeMinutes = safeHours == maximumHours ? 0 : min(max(minutes, 0), 59)
        return (safeHours * 60) + safeMinutes
    }

    static func components(totalMinutes: Int) -> (hours: Int, minutes: Int) {
        let clamped = min(max(totalMinutes, 0), maximumHours * 60)
        return (clamped / 60, clamped % 60)
    }

    static func label(totalMinutes: Int) -> String {
        let components = components(totalMinutes: totalMinutes)
        guard components.hours > 0 else { return "\(components.minutes) min" }

        let days = components.hours / 24
        let hours = components.hours % 24
        var parts: [String] = []
        if days > 0 { parts.append(days == 1 ? "1 day" : "\(days) days") }
        if hours > 0 { parts.append(hours == 1 ? "1 hour" : "\(hours) hours") }
        if components.minutes > 0 { parts.append("\(components.minutes) min") }
        return parts.joined(separator: " ")
    }

    static func compactLabel(totalMinutes: Int) -> String {
        let components = components(totalMinutes: totalMinutes)
        guard components.hours > 0 else { return "\(components.minutes)m" }
        guard components.minutes > 0 else { return "\(components.hours)h" }
        return "\(components.hours)h \(components.minutes)m"
    }
}
