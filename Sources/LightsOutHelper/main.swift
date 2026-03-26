import Foundation

let helperVersion = "1.0"
let socketPath = "/var/run/lightsout-helper.sock"
let hostsFilePath = "/etc/hosts"
let hostsBeginMarker = "# BEGIN LIGHTSOUT"
let hostsEndMarker = "# END LIGHTSOUT"

// MARK: - Domain Validation

func isValidDomain(_ domain: String) -> Bool {
    guard !domain.isEmpty, domain.count <= 253 else { return false }
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
    return domain.unicodeScalars.allSatisfy { allowed.contains($0) }
}

// MARK: - Hosts File Operations

func blockDomains(_ domains: [String]) -> (Bool, String) {
    let validDomains = domains.filter { isValidDomain($0) }
    guard !validDomains.isEmpty else {
        return (false, "No valid domains provided")
    }

    do {
        var contents = try String(contentsOfFile: hostsFilePath, encoding: .utf8)

        // Remove existing block if present
        if let beginRange = contents.range(of: hostsBeginMarker),
           let endRange = contents.range(of: hostsEndMarker) {
            let fullRange = contents.index(before: beginRange.lowerBound) < contents.startIndex
                ? beginRange.lowerBound..<endRange.upperBound
                : contents.index(before: beginRange.lowerBound)..<endRange.upperBound
            contents.removeSubrange(fullRange)
        }

        // Append new block
        var block = "\n\(hostsBeginMarker)\n"
        for domain in validDomains {
            block += "127.0.0.1 \(domain)\n"
        }
        block += hostsEndMarker + "\n"
        contents += block

        try contents.write(toFile: hostsFilePath, atomically: true, encoding: .utf8)
        flushDNS()
        return (true, "Blocked \(validDomains.count) domains")
    } catch {
        return (false, error.localizedDescription)
    }
}

func unblockDomains() -> (Bool, String) {
    do {
        var contents = try String(contentsOfFile: hostsFilePath, encoding: .utf8)

        if let beginRange = contents.range(of: hostsBeginMarker),
           let endRange = contents.range(of: hostsEndMarker) {
            // Include the newline before the marker if present
            var removeStart = beginRange.lowerBound
            if removeStart > contents.startIndex {
                let before = contents.index(before: removeStart)
                if contents[before] == "\n" {
                    removeStart = before
                }
            }
            // Include the newline after the end marker if present
            var removeEnd = endRange.upperBound
            if removeEnd < contents.endIndex && contents[removeEnd] == "\n" {
                removeEnd = contents.index(after: removeEnd)
            }
            contents.removeSubrange(removeStart..<removeEnd)
            try contents.write(toFile: hostsFilePath, atomically: true, encoding: .utf8)
        }

        flushDNS()
        return (true, "Unblocked")
    } catch {
        return (false, error.localizedDescription)
    }
}

func flushDNS() {
    let flush = Process()
    flush.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
    flush.arguments = ["-flushcache"]
    try? flush.run()
    flush.waitUntilExit()

    let killMDNS = Process()
    killMDNS.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
    killMDNS.arguments = ["-HUP", "mDNSResponder"]
    try? killMDNS.run()
    killMDNS.waitUntilExit()
}

// MARK: - Socket Server

func handleCommand(_ data: Data) -> Data {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let command = json["command"] as? String
    else {
        return makeResponse(ok: false, message: "Invalid JSON")
    }

    switch command {
    case "version":
        let resp: [String: Any] = ["status": "ok", "version": helperVersion]
        return (try? JSONSerialization.data(withJSONObject: resp)) ?? Data()

    case "block":
        guard let domains = json["domains"] as? [String] else {
            return makeResponse(ok: false, message: "Missing 'domains' array")
        }
        let (ok, msg) = blockDomains(domains)
        return makeResponse(ok: ok, message: msg)

    case "unblock":
        let (ok, msg) = unblockDomains()
        return makeResponse(ok: ok, message: msg)

    default:
        return makeResponse(ok: false, message: "Unknown command: \(command)")
    }
}

func makeResponse(ok: Bool, message: String) -> Data {
    let resp: [String: Any] = ["status": ok ? "ok" : "error", "message": message]
    return (try? JSONSerialization.data(withJSONObject: resp)) ?? Data()
}

// MARK: - Main

// Clean up socket on exit
func cleanup() {
    unlink(socketPath)
}

signal(SIGTERM, SIG_IGN)
let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termSource.setEventHandler {
    cleanup()
    exit(0)
}
termSource.resume()

signal(SIGINT, SIG_IGN)
let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
intSource.setEventHandler {
    cleanup()
    exit(0)
}
intSource.resume()

// Remove stale socket
unlink(socketPath)

// Create Unix domain socket
let fd = socket(AF_UNIX, SOCK_STREAM, 0)
guard fd >= 0 else {
    print("[LightsOutHelper] Failed to create socket")
    exit(1)
}

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
let pathBytes = socketPath.utf8CString
guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
    print("[LightsOutHelper] Socket path too long")
    exit(1)
}
withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
    ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
        for (i, byte) in pathBytes.enumerated() {
            dest[i] = byte
        }
    }
}

let bindResult = withUnsafePointer(to: &addr) { ptr in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
        bind(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}
guard bindResult == 0 else {
    print("[LightsOutHelper] Failed to bind socket: \(String(cString: strerror(errno)))")
    exit(1)
}

// Allow any local user to connect
chmod(socketPath, 0o666)

guard listen(fd, 5) == 0 else {
    print("[LightsOutHelper] Failed to listen: \(String(cString: strerror(errno)))")
    exit(1)
}

print("[LightsOutHelper] Listening on \(socketPath)")

// Accept connections on a background queue, keep main run loop alive
DispatchQueue.global(qos: .utility).async {
    while true {
        let clientFd = accept(fd, nil, nil)
        guard clientFd >= 0 else { continue }

        // Read request (up to 64KB)
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(clientFd, &buffer, buffer.count)
        if bytesRead > 0 {
            let requestData = Data(buffer[0..<bytesRead])
            let responseData = handleCommand(requestData)
            responseData.withUnsafeBytes { ptr in
                _ = write(clientFd, ptr.baseAddress!, responseData.count)
            }
        }
        close(clientFd)
    }
}

dispatchMain()
