import Foundation

class HostFileManager {
    private var isBlocking = false

    func blockDomains(_ domains: [String]) {
        guard !domains.isEmpty, !isBlocking else { return }

        let command: [String: Any] = ["command": "block", "domains": domains]
        if let response = HelperClient.sendCommand(command),
           response["status"] as? String == "ok" {
            isBlocking = true
            print("[LightsOut] Domains blocked via helper")
        } else {
            print("[LightsOut] Helper unavailable, falling back to osascript")
            blockDomainsLegacy(domains)
        }
    }

    func unblockDomains() {
        guard isBlocking else { return }

        let command: [String: Any] = ["command": "unblock"]
        if let response = HelperClient.sendCommand(command),
           response["status"] as? String == "ok" {
            isBlocking = false
            print("[LightsOut] Domains unblocked via helper")
        } else {
            print("[LightsOut] Helper unavailable, falling back to osascript")
            unblockDomainsLegacy()
        }
    }

    // MARK: - Legacy Fallback (osascript with admin prompt)

    private func blockDomainsLegacy(_ domains: [String]) {
        var entries = ""
        for domain in domains {
            entries += "127.0.0.1 \(domain)\\n"
        }

        let script = """
        do shell script "printf '\\n\(Constants.hostsBeginMarker)\\n\(entries)\(Constants.hostsEndMarker)\\n' >> \(Constants.hostsFilePath) && dscacheutil -flushcache && killall -HUP mDNSResponder" with administrator privileges
        """

        runOsascript(script)
        isBlocking = true
    }

    private func unblockDomainsLegacy() {
        let script = """
        do shell script "sed -i '' '/\(Constants.hostsBeginMarker)/,/\(Constants.hostsEndMarker)/d' \(Constants.hostsFilePath) && dscacheutil -flushcache && killall -HUP mDNSResponder" with administrator privileges
        """

        runOsascript(script)
        isBlocking = false
    }

    private func runOsascript(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
        process.waitUntilExit()
    }
}
