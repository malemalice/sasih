/// Pure version-string comparison — no I/O, trivially testable.
public enum VersionComparison {
    /// True if `lhs` is a strictly newer semantic version than `rhs`.
    /// Compares dotted numeric components (e.g. "1.2.0" vs "1.10.0" compares
    /// numerically, not lexicographically); missing or non-numeric
    /// components are treated as 0.
    public static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let l = components(of: lhs)
        let r = components(of: rhs)
        for i in 0..<max(l.count, r.count) {
            let a = i < l.count ? l[i] : 0
            let b = i < r.count ? r[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func components(of version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}
