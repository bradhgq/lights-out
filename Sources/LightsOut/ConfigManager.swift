import Foundation
import LightsOutCore

/// macOS-specific extension: resolve display-name app lists to bundle IDs via the
/// installed-app scanner. iOS doesn't have access to this (opaque tokens only), so
/// these helpers are not in the shared core.
extension LightsOutConfig {
    /// Returns the effective set of blocked bundle IDs.
    /// Prefers `blockedAppBundleIDs` if set; otherwise falls back to name-based lookup.
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

    /// Get a `Date` for a given "HH:mm" time string on today's date.
    func dateForTime(_ timeString: String) -> Date? {
        guard let (hour, minute) = LightsOutCore.parseTime(timeString) else { return nil }
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
