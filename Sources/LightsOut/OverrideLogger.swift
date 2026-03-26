import Foundation

struct OverrideEntry: Codable {
    let timestamp: String
    let appName: String
    let phase: String
    let frictionDelay: Int
}

class OverrideLogger {
    func log(appName: String, phase: String, frictionDelay: Int) {
        let entry = OverrideEntry(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            appName: appName,
            phase: phase,
            frictionDelay: frictionDelay
        )

        var entries = loadEntries()
        entries.append(entry)
        saveEntries(entries)
    }

    func todayEntries() -> [OverrideEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()

        return loadEntries().filter { entry in
            guard let date = formatter.date(from: entry.timestamp) else { return false }
            return date >= today
        }
    }

    private func loadEntries() -> [OverrideEntry] {
        let file = Constants.overridesFile
        guard let data = try? Data(contentsOf: file),
              let entries = try? JSONDecoder().decode([OverrideEntry].self, from: data)
        else { return [] }
        return entries
    }

    private func saveEntries(_ entries: [OverrideEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(entries) else { return }

        let dir = Constants.configDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try? data.write(to: Constants.overridesFile)
    }
}
