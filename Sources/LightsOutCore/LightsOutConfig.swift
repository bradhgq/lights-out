import Foundation

/// Cross-platform configuration schema for Lights Out.
///
/// This is the pure-data view of user settings. Both the macOS app and the iOS app
/// persist the same shape, though *where* they persist it differs:
/// - **macOS** reads/writes `~/.lightsout/config.json`.
/// - **iOS** writes to App Group `UserDefaults` (since extensions need to read it),
///   because iOS apps can't share arbitrary files with extensions without App Groups.
///
/// Some fields are macOS-only (hosts-file domain blocking, menubar countdown) and
/// some are iOS-only (Family Controls token selection). Platform-specific fields
/// are documented inline; deserializers on each platform are permissive about
/// ignoring fields they don't use.
public struct LightsOutConfig: Codable, Equatable {

    // MARK: - Phase times (HH:mm, 24-hour)

    public var amberTime: String
    public var winddownTime: String
    public var lightsOutTime: String
    public var morningResetTime: String

    // MARK: - App blocking (macOS: bundle IDs; iOS: opaque tokens stored elsewhere)

    /// Legacy display names (macOS only). New installs should prefer `blockedAppBundleIDs`.
    public var blockedApps: [String]

    /// Preferred bundle-ID list for macOS. iOS ignores this (uses FamilyControls tokens).
    public var blockedAppBundleIDs: [String]?

    /// Domains blocked via `/etc/hosts` (macOS only). iOS uses ManagedSettings web domains
    /// selected through the FamilyActivityPicker.
    public var blockedDomains: [String]

    /// Legacy whitelist display names (macOS only).
    public var whitelistedApps: [String]

    /// Whitelisted bundle IDs that are allowed even during lights-out (macOS only).
    public var whitelistedAppBundleIDs: [String]?

    // MARK: - Shared behavior

    /// Bedtime checklist items surfaced during wind-down (both platforms).
    public var checklist: [String]

    /// Override-step delays in seconds. Length controls how many override steps the user
    /// gets before being escalated to the emergency-override path.
    public var frictionDelaysSeconds: [Int]

    /// If true, invoking the Shortcuts automation named `shortcutName` triggers lights-out.
    /// On iOS this is also used as the grayscale Shortcut name unless
    /// `grayscaleShortcutName` is explicitly set.
    public var enableShortcutTrigger: Bool

    /// Name of the user-created Shortcut that the app calls via `shortcuts://run-shortcut`.
    public var shortcutName: String

    /// Show a live countdown in the macOS menu bar icon (macOS only).
    public var showCountdownInMenuBar: Bool

    // MARK: - iOS-specific

    /// Name of the user-created Shortcut that toggles Color Filters ON (grayscale).
    /// iOS cannot toggle Color Filters programmatically, so we delegate to a user
    /// Shortcut automation. Defaults to a reasonable value the onboarding wizard
    /// suggests creating.
    public var grayscaleOnShortcutName: String?

    /// Name of the user-created Shortcut that toggles Color Filters OFF.
    public var grayscaleOffShortcutName: String?

    // MARK: - CodingKeys (snake_case on disk)

    enum CodingKeys: String, CodingKey {
        case amberTime = "amber_time"
        case winddownTime = "winddown_time"
        case lightsOutTime = "lights_out_time"
        case morningResetTime = "morning_reset_time"
        case blockedApps = "blocked_apps"
        case blockedAppBundleIDs = "blocked_app_bundle_ids"
        case blockedDomains = "blocked_domains"
        case whitelistedApps = "whitelisted_apps"
        case whitelistedAppBundleIDs = "whitelisted_app_bundle_ids"
        case checklist
        case frictionDelaysSeconds = "friction_delays_seconds"
        case enableShortcutTrigger = "enable_shortcut_trigger"
        case shortcutName = "shortcut_name"
        case showCountdownInMenuBar = "show_countdown_in_menu_bar"
        case grayscaleOnShortcutName = "grayscale_on_shortcut_name"
        case grayscaleOffShortcutName = "grayscale_off_shortcut_name"
    }

    public init(
        amberTime: String,
        winddownTime: String,
        lightsOutTime: String,
        morningResetTime: String,
        blockedApps: [String] = [],
        blockedAppBundleIDs: [String]? = nil,
        blockedDomains: [String] = [],
        whitelistedApps: [String] = [],
        whitelistedAppBundleIDs: [String]? = nil,
        checklist: [String] = [],
        frictionDelaysSeconds: [Int] = [60, 180, 600],
        enableShortcutTrigger: Bool = false,
        shortcutName: String = "Bedtime",
        showCountdownInMenuBar: Bool = true,
        grayscaleOnShortcutName: String? = nil,
        grayscaleOffShortcutName: String? = nil
    ) {
        self.amberTime = amberTime
        self.winddownTime = winddownTime
        self.lightsOutTime = lightsOutTime
        self.morningResetTime = morningResetTime
        self.blockedApps = blockedApps
        self.blockedAppBundleIDs = blockedAppBundleIDs
        self.blockedDomains = blockedDomains
        self.whitelistedApps = whitelistedApps
        self.whitelistedAppBundleIDs = whitelistedAppBundleIDs
        self.checklist = checklist
        self.frictionDelaysSeconds = frictionDelaysSeconds
        self.enableShortcutTrigger = enableShortcutTrigger
        self.shortcutName = shortcutName
        self.showCountdownInMenuBar = showCountdownInMenuBar
        self.grayscaleOnShortcutName = grayscaleOnShortcutName
        self.grayscaleOffShortcutName = grayscaleOffShortcutName
    }

    /// Sensible defaults used when no config file exists yet.
    public static let defaults = LightsOutConfig(
        amberTime: "22:30",
        winddownTime: "23:00",
        lightsOutTime: "23:30",
        morningResetTime: "06:00",
        blockedApps: [],
        blockedAppBundleIDs: [
            "com.google.Chrome", "org.mozilla.firefox", "com.apple.Safari",
            "com.westbridge.stremio4-mac",
        ],
        blockedDomains: [
            "youtube.com", "www.youtube.com",
            "reddit.com", "www.reddit.com",
            "twitter.com", "x.com",
        ],
        whitelistedApps: [],
        whitelistedAppBundleIDs: [
            "com.apple.Terminal", "com.apple.Notes", "com.apple.iBooksX",
            "com.spotify.client", "com.googlecode.iterm2",
        ],
        checklist: [
            "Brush teeth",
            "Set out clothes for tomorrow",
            "Phone on charger in other room",
            "Review tomorrow's calendar",
        ],
        frictionDelaysSeconds: [60, 180, 600],
        enableShortcutTrigger: false,
        shortcutName: "Bedtime",
        showCountdownInMenuBar: true,
        grayscaleOnShortcutName: "Lights Out — Grayscale On",
        grayscaleOffShortcutName: "Lights Out — Grayscale Off"
    )

    // MARK: - Validation

    /// Validate phase-time ordering relative to the morning-reset anchor.
    /// Returns a list of human-readable error strings (empty = valid).
    public func validate() -> [String] {
        var errors: [String] = []

        guard let morning = timeToMinutes(morningResetTime) else {
            errors.append("Invalid morning_reset_time: \(morningResetTime)")
            return errors
        }
        guard let amber = timeToMinutes(amberTime) else {
            errors.append("Invalid amber_time: \(amberTime)")
            return errors
        }
        guard let winddown = timeToMinutes(winddownTime) else {
            errors.append("Invalid winddown_time: \(winddownTime)")
            return errors
        }
        guard let lightsOut = timeToMinutes(lightsOutTime) else {
            errors.append("Invalid lights_out_time: \(lightsOutTime)")
            return errors
        }

        // Normalize to minutes-since-morning-reset (in a 24-hour window).
        // This makes a "22:30 amber, 06:00 morning" schedule comparable cleanly.
        let day = 24 * 60
        let a = (amber - morning + day) % day
        let w = (winddown - morning + day) % day
        let l = (lightsOut - morning + day) % day

        if a == 0 {
            errors.append("amber_time must be different from morning_reset_time")
        }
        if w < a {
            errors.append(
                "winddown_time (\(winddownTime)) must be at or after amber_time (\(amberTime)) in the daily cycle"
            )
        }
        if l < w {
            errors.append(
                "lights_out_time (\(lightsOutTime)) must be at or after winddown_time (\(winddownTime)) in the daily cycle"
            )
        }

        return errors
    }

    /// Derive a `TimelineConfig` for the pure timeline math in `Timeline.swift`.
    public var timelineConfig: TimelineConfig {
        TimelineConfig(
            morningResetTime: morningResetTime,
            amberTime: amberTime,
            winddownTime: winddownTime,
            lightsOutTime: lightsOutTime
        )
    }

    // MARK: - Private

    private func timeToMinutes(_ time: String) -> Int? {
        guard let (h, m) = parseTime(time) else { return nil }
        return h * 60 + m
    }
}
