import Foundation

enum HelperInstaller {
    static let expectedVersion = "1.0"
    static let socketPath = "/var/run/lightsout-helper.sock"
    static let daemonLabel = "com.lightsout.helper"
    static let helperInstallPath = "/Library/PrivilegedHelperTools/com.lightsout.helper"
    static let plistInstallPath = "/Library/LaunchDaemons/com.lightsout.helper.plist"

    /// Check if the helper is installed and running with the correct version.
    /// If not, install/update it (triggers one admin password prompt).
    static func installIfNeeded() {
        if let version = queryHelperVersion(), version == expectedVersion {
            print("[LightsOut] Helper already installed (v\(version))")
            return
        }
        print("[LightsOut] Helper not found or version mismatch — installing...")
        install()
    }

    /// Send a version command to the helper socket and return the version string.
    private static func queryHelperVersion() -> String? {
        guard let responseJSON = HelperClient.sendCommand(["command": "version"]),
              let version = responseJSON["version"] as? String
        else {
            return nil
        }
        return version
    }

    /// Install the helper binary and launchd plist using a single admin-privileged osascript call.
    private static func install() {
        let bundlePath = Bundle.main.bundlePath
        let helperSrc = "\(bundlePath)/Contents/MacOS/LightsOutHelper"
        let plistSrc = "\(bundlePath)/Contents/Resources/com.lightsout.helper.plist"

        // Verify source files exist
        guard FileManager.default.fileExists(atPath: helperSrc) else {
            print("[LightsOut] Helper binary not found at \(helperSrc)")
            return
        }
        guard FileManager.default.fileExists(atPath: plistSrc) else {
            print("[LightsOut] Launchd plist not found at \(plistSrc)")
            return
        }

        let shellCommands = [
            "mkdir -p /Library/PrivilegedHelperTools",
            "cp '\(helperSrc)' '\(helperInstallPath)'",
            "chown root:wheel '\(helperInstallPath)'",
            "chmod 755 '\(helperInstallPath)'",
            "cp '\(plistSrc)' '\(plistInstallPath)'",
            "chown root:wheel '\(plistInstallPath)'",
            "launchctl bootout system/\(daemonLabel) 2>/dev/null; true",
            "launchctl bootstrap system '\(plistInstallPath)'",
        ].joined(separator: " && ")

        let script = """
        do shell script "\(shellCommands)" with administrator privileges
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errPipe = Pipe()
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                print("[LightsOut] Helper installed successfully")
            } else {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                print("[LightsOut] Helper install failed: \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        } catch {
            print("[LightsOut] Failed to run installer: \(error.localizedDescription)")
        }
    }
}

/// Shared Unix domain socket client for communicating with the helper daemon.
enum HelperClient {
    static let socketPath = "/var/run/lightsout-helper.sock"

    /// Send a JSON command to the helper and return the parsed response, or nil on failure.
    static func sendCommand(_ command: [String: Any]) -> [String: Any]? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for (i, byte) in pathBytes.enumerated() {
                    dest[i] = byte
                }
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else { return nil }

        // Send
        guard let requestData = try? JSONSerialization.data(withJSONObject: command) else { return nil }
        let sent = requestData.withUnsafeBytes { ptr in
            write(fd, ptr.baseAddress!, requestData.count)
        }
        guard sent == requestData.count else { return nil }

        // Receive (up to 64KB)
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else { return nil }

        let responseData = Data(buffer[0..<bytesRead])
        return try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
    }
}
