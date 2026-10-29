import Foundation

/// Saved control values per camera model (vendor:product), in UserDefaults.
struct SettingsStore {
    var defaults: UserDefaults = .standard
    private let key = "savedControls"

    func load(_ modelKey: String) -> [String: Int] {
        (defaults.dictionary(forKey: key)?[modelKey] as? [String: Int]) ?? [:]
    }

    func save(_ values: [String: Int], for modelKey: String) {
        var all = defaults.dictionary(forKey: key) ?? [:]
        all[modelKey] = values
        defaults.set(all, forKey: key)
    }
}
