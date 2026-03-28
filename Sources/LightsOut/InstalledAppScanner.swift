import AppKit

struct InstalledAppInfo: Identifiable, Comparable {
    let id: String          // bundle identifier
    let displayName: String // user-facing name
    let url: URL            // path to .app bundle

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    static func < (lhs: InstalledAppInfo, rhs: InstalledAppInfo) -> Bool {
        lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    // Identifiable + Equatable by bundle ID only
    static func == (lhs: InstalledAppInfo, rhs: InstalledAppInfo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class InstalledAppScanner {
    private(set) var apps: [InstalledAppInfo] = []

    init() {
        scan()
    }

    @discardableResult
    func scan() -> [InstalledAppInfo] {
        var found: [String: InstalledAppInfo] = [:] // keyed by bundle ID to dedup

        let searchDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]

        for dir in searchDirs {
            scanDirectory(dir, depth: 0, maxDepth: 2, into: &found)
        }

        apps = found.values.sorted()
        return apps
    }

    /// Resolve a display name to a bundle identifier, case-insensitive.
    func bundleID(forDisplayName name: String) -> String? {
        apps.first { $0.displayName.lowercased() == name.lowercased() }?.id
    }

    /// Resolve a bundle identifier to a display name.
    func displayName(forBundleID bundleID: String) -> String? {
        apps.first { $0.id == bundleID }?.displayName
    }

    /// Resolve a bundle identifier to full app info.
    func appInfo(forBundleID bundleID: String) -> InstalledAppInfo? {
        apps.first { $0.id == bundleID }
    }

    // MARK: - Private

    private func scanDirectory(_ dir: URL, depth: Int, maxDepth: Int, into found: inout [String: InstalledAppInfo]) {
        guard depth <= maxDepth else { return }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return }

        for url in contents {
            if url.pathExtension == "app" {
                if let info = appInfo(at: url) {
                    // Don't overwrite — prefer /Applications over ~/Applications
                    if found[info.id] == nil {
                        found[info.id] = info
                    }
                }
            } else if depth < maxDepth {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir {
                    scanDirectory(url, depth: depth + 1, maxDepth: maxDepth, into: &found)
                }
            }
        }
    }

    private func appInfo(at url: URL) -> InstalledAppInfo? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier
        else { return nil }

        // Prefer CFBundleDisplayName, fall back to CFBundleName, then filename
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        return InstalledAppInfo(id: bundleID, displayName: displayName, url: url)
    }
}
