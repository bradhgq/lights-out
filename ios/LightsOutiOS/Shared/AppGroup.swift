import Foundation

/// Constants for the shared App Group used by the main app and all three extensions.
///
/// The App Group is the only way for the main app and its extensions to share data —
/// `UserDefaults(suiteName:)` and file URLs scoped to the container both route through
/// this identifier. Keep this identifier in sync with each target's entitlements plist.
public enum AppGroup {
    /// Group identifier registered in every target's entitlements.
    public static let identifier = "group.com.lightsout.shared"

    /// Shared UserDefaults for config + runtime state visible to extensions.
    public static var userDefaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            // This is a programmer error: missing/misspelled App Group entitlement.
            // Failing loud beats silently falling back to standard defaults and
            // having extensions see stale/no data.
            fatalError(
                "App Group '\(identifier)' is not available. Check entitlements on all targets."
            )
        }
        return defaults
    }

    /// Shared container URL, useful for writing larger blobs than defaults should hold.
    public static var containerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            fatalError(
                "App Group container '\(identifier)' unavailable. Check entitlements."
            )
        }
        return url
    }
}

/// Keys for values stored in the shared App Group UserDefaults.
///
/// Grouped here (rather than scattered across call sites) so the extension targets can
/// see the exact same key names at a glance — a typo here silently breaks the main app's
/// communication with the extension, so centralization is important.
public enum AppGroupKey {
    /// `Data` — JSON-encoded `LightsOutConfig`.
    public static let config = "lightsout.config"

    /// `Data` — JSON-encoded `FamilyActivitySelection` tokens the user picked.
    public static let activitySelection = "lightsout.activitySelection"

    /// `String` — the current phase (`Phase.rawValue`). The monitor extension writes
    /// this at phase boundaries; the shield configuration extension reads it to choose
    /// which shield style to render.
    public static let currentPhase = "lightsout.currentPhase"

    /// `Date` — the timestamp of the last phase transition.
    public static let currentPhaseSince = "lightsout.currentPhaseSince"

    /// `Data` — JSON-encoded `[String: Date]` mapping ApplicationToken hash to expiry,
    /// representing per-app temporary overrides the friction flow granted.
    public static let activeOverrides = "lightsout.activeOverrides"
}
