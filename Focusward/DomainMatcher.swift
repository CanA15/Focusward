import Foundation

enum DomainMatcher {
    static func normalizeRule(_ rawValue: String) -> String? {
        var candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }

        if !candidate.contains("://") {
            candidate = "https://\(candidate)"
        }

        guard var host = hostname(from: candidate) else { return nil }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }

        guard !host.isEmpty, host.contains("."), !host.contains(" ") else {
            return nil
        }

        return host
    }

    static func hostname(from urlString: String) -> String? {
        guard let host = URL(string: urlString)?.host?.lowercased() else {
            return nil
        }
        return host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    static func isBlocked(hostname: String, by rules: [String]) -> Bool {
        let normalizedHostname = hostname.lowercased()
        return rules.contains { rule in
            normalizedHostname == rule || normalizedHostname.hasSuffix(".\(rule)")
        }
    }
}
