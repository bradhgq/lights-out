import Foundation

struct LightsOutConfig: Codable {
    var amberTime: String
    var winddownTime: String
    var lightsOutTime: String
    var morningResetTime: String
    var blockedApps: [String]           // legacy: display names
    var blockedAppBundleIDs: [String]?  // preferred: bundle identifiers
    var blockedDomains: [String]
    var whitelistedApps: [String]              // legacy: display names
    var whitelistedAppBundleIDs: [String]?     // preferred: bundle identifiers
    var checklist: [String]
    var frictionDelaysSeconds: [Int]
    var enableShortcutTrigger: Bool
    var shortcutName: String
    var showCountdownInMenuBar: Bool

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
    }

    static let defaults = LightsOutConfig(
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
        showCountdownInMenuBar: true
    )

    /// Returns the effective set of blocked bundle IDs.
    /// Prefers blockedAppBundleIDs if set; otherwise falls back to name-based lookup.
    func effectiveBlockedBundleIDs(scanner: InstalledAppScanner) -> [String] {
        if let ids = blockedAppBundleIDs, !ids.isEmpty {
            return ids
        }
        return blockedApps.compactMap { scanner.bundleID(forDisplayName: $0) }
    }

    /// Returns the effective set of whitelisted bundle IDs.
    func effectiveWhitelistedBundleIDs(scanner: InstalledAppScanner) -> [String] {
        if let ids = whitelistedAppBundleIDs, !ids.isEmpty {
            return ids
        }
        return whitelistedApps.compactMap { scanner.bundleID(forDisplayName: $0) }
    }

    /// Parse a time string like "22:30" into hour and minute components.
    func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    /// Convert a time string to minutes-since-midnight (0–1439).
    private func timeToMinutes(_ time: String) -> Int? {
        guard let (h, m) = parseTime(time) else { return nil }
        return h * 60 + m
    }

    /// Validate that phases are in chronological order within a 24-hour cycle starting from morning reset.
    func validate() -> [String] {
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

        // Normalize times relative to morning reset (so morning = 0)
        let totalMinutes = 24 * 60
        let normAmber = (amber - morning + totalMinutes) % totalMinutes
        let normWinddown = (winddown - morning + totalMinutes) % totalMinutes
        let normLightsOut = (lightsOut - morning + totalMinutes) % totalMinutes

        if normAmber == 0 {
            errors.append("amber_time must be different from morning_reset_time")
        }
        if normWinddown < normAmber {
            errors.append("winddown_time (\(winddownTime)) must be at or after amber_time (\(amberTime)) in the daily cycle")
        }
        if normLightsOut < normWinddown {
            errors.append("lights_out_time (\(lightsOutTime)) must be at or after winddown_time (\(winddownTime)) in the daily cycle")
        }

        return errors
    }

    /// Get a Date for a given time string on today's date.
    func dateForTime(_ timeString: String) -> Date? {
        guard let (hour, minute) = parseTime(timeString) else { return nil }
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }
}

class ConfigManager {
    var config: LightsOutConfig
    let scanner: InstalledAppScanner
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var suppressFileWatch = false
    var onConfigReloaded: (() -> Void)?

    init() {
        scanner = InstalledAppScanner()

        let fm = FileManager.default
        let configDir = Constants.configDirectory
        let configFile = Constants.configFile

        // Ensure directory exists
        if !fm.fileExists(atPath: configDir.path) {
            try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        }

        // Load or create config
        if fm.fileExists(atPath: configFile.path),
           let data = try? Data(contentsOf: configFile),
           let loaded = try? JSONDecoder().decode(LightsOutConfig.self, from: data)
        {
            config = loaded
        } else {
            config = LightsOutConfig.defaults
            save()
        }

        // Migrate name-based blocked/whitelisted to bundle IDs
        migrateIfNeeded()

        let errors = config.validate()
        for error in errors {
            print("[LightsOut] Config warning: \(error)")
        }

        startWatching()
    }

    deinit {
        stopWatching()
    }

    /// Migrate legacy name-based app lists to bundle IDs.
    private func migrateIfNeeded() {
        var changed = false

        if config.blockedAppBundleIDs == nil && !config.blockedApps.isEmpty {
            let resolved = config.blockedApps.compactMap { name -> String? in
                if let id = scanner.bundleID(forDisplayName: name) {
                    return id
                }
                print("[LightsOut] Migration: could not resolve '\(name)' to a bundle ID")
                return nil
            }
            config.blockedAppBundleIDs = resolved
            changed = true
        }

        if config.whitelistedAppBundleIDs == nil && !config.whitelistedApps.isEmpty {
            let resolved = config.whitelistedApps.compactMap { name -> String? in
                if let id = scanner.bundleID(forDisplayName: name) {
                    return id
                }
                print("[LightsOut] Migration: could not resolve '\(name)' to a bundle ID")
                return nil
            }
            config.whitelistedAppBundleIDs = resolved
            changed = true
        }

        if changed {
            save()
            print("[LightsOut] Migrated config to bundle identifiers")
        }
    }

    private func startWatching() {
        let path = Constants.configFile.path
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if self.suppressFileWatch { return }
            // Small delay to let the editor finish writing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.reload()
                print("[LightsOut] Config reloaded from file change")
                self.onConfigReloaded?()
            }
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        source.resume()
        dispatchSource = source
    }

    private func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    func save() {
        suppressFileWatch = true
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else {
            suppressFileWatch = false
            return
        }
        try? data.write(to: Constants.configFile)
        // Re-enable file watching after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.suppressFileWatch = false
        }
    }

    func reload() {
        guard let data = try? Data(contentsOf: Constants.configFile),
              let loaded = try? JSONDecoder().decode(LightsOutConfig.self, from: data)
        else { return }

        let errors = loaded.validate()
        if !errors.isEmpty {
            for error in errors {
                print("[LightsOut] Config warning: \(error)")
            }
        }
        config = loaded
    }
}
