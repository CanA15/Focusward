import Foundation

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

        if components.hours == 0 {
            return "\(components.minutes) min"
        }

        if components.hours >= 24 {
            let days = components.hours / 24
            let remainingHours = components.hours % 24
            var parts = [days == 1 ? "1 day" : "\(days) days"]

            if remainingHours > 0 {
                parts.append(remainingHours == 1 ? "1 hour" : "\(remainingHours) hours")
            }
            if components.minutes > 0 {
                parts.append("\(components.minutes) min")
            }

            return parts.joined(separator: " ")
        }

        if components.minutes == 0 {
            return components.hours == 1 ? "1 hour" : "\(components.hours) hours"
        }

        let hourLabel = components.hours == 1 ? "1 hour" : "\(components.hours) hours"
        return "\(hourLabel) \(components.minutes) min"
    }

    static func compactLabel(totalMinutes: Int) -> String {
        let components = components(totalMinutes: totalMinutes)
        guard components.hours > 0 else { return "\(components.minutes)m" }
        guard components.minutes > 0 else { return "\(components.hours)h" }
        return "\(components.hours)h \(components.minutes)m"
    }
}
