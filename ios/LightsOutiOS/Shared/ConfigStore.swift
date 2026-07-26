import Foundation
import LightsOutCore

/// Persistence layer for `LightsOutConfig` on iOS.
///
/// On macOS the config is a JSON file in the home directory; on iOS, extensions can't
/// read arbitrary files from the main app, so we store the same JSON blob as a `Data`
/// value inside App Group UserDefaults instead. Readers (the main app, the monitor
/// extension, and the shield extensions) all go through this store.
public enum ConfigStore {

    /// Load the current config, returning `.defaults` if nothing is stored yet.
    /// Decoding failures fall back to defaults and log — we'd rather degrade gracefully
    /// than crash an extension.
    public static func load() -> LightsOutConfig {
        guard let data = AppGroup.userDefaults.data(forKey: AppGroupKey.config) else {
            return .defaults
        }
        do {
            return try JSONDecoder().decode(LightsOutConfig.self, from: data)
        } catch {
            NSLog("[LightsOut] Failed to decode config: \(error); using defaults")
            return .defaults
        }
    }

    /// Persist the given config. Both the main app and (in theory) extensions can call
    /// this, though in practice only the main app writes.
    public static func save(_ config: LightsOutConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            AppGroup.userDefaults.set(data, forKey: AppGroupKey.config)
        } catch {
            NSLog("[LightsOut] Failed to encode config: \(error)")
        }
    }

    /// Whether a config has been persisted yet — used by onboarding to detect
    /// first launch.
    public static var hasStoredConfig: Bool {
        AppGroup.userDefaults.data(forKey: AppGroupKey.config) != nil
    }
}
