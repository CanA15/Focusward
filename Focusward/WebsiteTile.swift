enum WebsiteTile {
    static let colorCount = 8

    static func letter(for domain: String) -> String {
        domain.first.map { String($0).uppercased() } ?? ""
    }

    // The same website must keep its color after a relaunch, so the index uses a fixed hash.
    static func colorIndex(for domain: String) -> Int {
        let hash = domain.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 997 }
        return hash % colorCount
    }
}
