import Foundation

/// Constants for the shared App Group used by the main app and all three extensions.
///
/// The App Group is the only way for the main app and its extensions to share data —
/// `UserDefaults(suiteName:)` and file URLs scoped to the container both route through
/// this identifier. Keep this identifier in sync with each target's entitlements plist.
public enum AppGroup {
    /// Group identifier registered in every target's entitlements.
    /// Must stay in sync with `com.apple.security.application-groups` in project.yml.
    public static let identifier = "group.fyi.hgq.lightsout"

    /// Shared UserDefaults for config + runtime state visible to extensions.
    ///
    /// Note this cannot detect a missing App Group entitlement:
    /// `UserDefaults(suiteName:)` returns a valid instance for any well-formed suite
    /// name, entitled or not. An unentitled build therefore gets a *private* suite per
    /// process, and the app and extensions silently stop seeing each other's writes.
    /// If phase state appears not to propagate to the extensions, suspect the
    /// entitlement first — there will be no crash and no error to go on.
    public static var userDefaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            // Only reachable if `identifier` is malformed (e.g. empty), which would be
            // a build-time mistake in this file rather than a provisioning problem.
            fatalError("App Group suite name '\(identifier)' is malformed.")
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

    /// `String` — phase store name written by the shield-action extension when the
    /// user taps "Request override". The main app reads it on foreground (and via
    /// the `lightsout://override` URL) to present the friction sheet, then clears it.
    public static let pendingOverride = "lightsout.pendingOverride"

    /// `Int` — overrides granted since the last morning reset, driving escalation.
    public static let overrideCount = "lightsout.overrideCount"

    /// `Date` — expiry of the currently granted override, per phase store name.
    /// Keyed as `overrideExpiry(for:)` so each phase store expires independently.
    /// Persisted rather than held in memory so that force-quitting the app during an
    /// override doesn't strand the shield in the "lifted" state.
    public static func overrideExpiry(for storeName: String) -> String {
        "lightsout.overrideExpiry.\(storeName)"
    }
}
