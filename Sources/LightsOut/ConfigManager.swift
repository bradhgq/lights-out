import Foundation

struct LightsOutConfig: Codable {
    var amberTime: String
    var winddownTime: String
    var lightsOutTime: String
    var morningResetTime: String
    var blockedApps: [String]
    var blockedDomains: [String]
    var whitelistedApps: [String]
    var checklist: [String]
    var frictionDelaysSeconds: [Int]
    var enableShortcutTrigger: Bool
    var shortcutName: String

    enum CodingKeys: String, CodingKey {
        case amberTime = "amber_time"
        case winddownTime = "winddown_time"
        case lightsOutTime = "lights_out_time"
        case morningResetTime = "morning_reset_time"
        case blockedApps = "blocked_apps"
        case blockedDomains = "blocked_domains"
        case whitelistedApps = "whitelisted_apps"
        case checklist
        case frictionDelaysSeconds = "friction_delays_seconds"
        case enableShortcutTrigger = "enable_shortcut_trigger"
        case shortcutName = "shortcut_name"
    }

    static let defaults = LightsOutConfig(
        amberTime: "22:30",
        winddownTime: "23:00",
        lightsOutTime: "23:30",
        morningResetTime: "06:00",
        blockedApps: ["Google Chrome", "Firefox", "Safari", "Stremio"],
        blockedDomains: [
            "youtube.com", "www.youtube.com",
            "reddit.com", "www.reddit.com",
            "twitter.com", "x.com",
        ],
        whitelistedApps: ["Terminal", "Notes", "Books", "Spotify", "iTerm2"],
        checklist: [
            "Brush teeth",
            "Set out clothes for tomorrow",
            "Phone on charger in other room",
            "Review tomorrow's calendar",
        ],
        frictionDelaysSeconds: [60, 180, 600],
        enableShortcutTrigger: true,
        shortcutName: "Bedtime"
    )

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
    /// Times wrap around midnight (e.g. morning 06:00, amber 22:30, winddown 23:00, lightsOut 00:30 is valid).
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
    /// If the time is before morningReset, it's treated as tomorrow (for overnight scheduling).
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
    private(set) var config: LightsOutConfig
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    var onConfigReloaded: (() -> Void)?

    init() {
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

        let errors = config.validate()
        for error in errors {
            print("[LightsOut] Config warning: \(error)")
        }

        startWatching()
    }

    deinit {
        stopWatching()
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: Constants.configFile)
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
