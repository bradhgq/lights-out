import Foundation

class ShortcutTrigger {
    func run(shortcutName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", shortcutName]

        let errPipe = Pipe()
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                print("[LightsOut] Shortcut '\(shortcutName)' failed: \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        } catch {
            print("[LightsOut] Could not run shortcut '\(shortcutName)': \(error.localizedDescription)")
        }
    }
}
