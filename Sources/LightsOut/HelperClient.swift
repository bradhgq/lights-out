import Foundation

/// Shared Unix domain socket client for communicating with the privileged
/// helper daemon (`com.lightsout.helper`).
///
/// Installation of the helper is owned by the nix-darwin module, not by the
/// app. An earlier iteration of this file also contained a `HelperInstaller`
/// type that shelled out to `osascript ... with administrator privileges` to
/// copy the binary into `/Library/PrivilegedHelperTools` and bootstrap the
/// LaunchDaemon. That flow triggered an admin-password prompt at every login
/// whenever the helper socket wasn't ready yet, and it clobbered the plist
/// managed by nix-darwin. It has been removed — if the helper is unreachable,
/// callers fall back to their own osascript paths (see `HostFileManager`).
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
