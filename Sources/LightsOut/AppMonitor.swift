import AppKit
import Foundation
import LightsOutCore

class AppMonitor {
    /// Blocked app bundle identifiers
    private var blockedBundleIDs: Set<String>
    private var frictionDelays: [Int]
    private let frictionOverlay: FrictionOverlayController
    private let overrideLogger: OverrideLogger

    /// Keyed by bundle ID
    private var overrideCounts: [String: Int] = [:]
    private var currentPhase: Phase = .idle
    private var isMonitoring = false
    private var pollingTimer: Timer?
    private var temporarilyAllowed: Set<String> = []  // bundle IDs
    private var overrideTimers: [String: Timer] = [:]  // bundle ID → timer
    private(set) var overrideExpiries: [String: Date] = [:]  // bundle ID → expiry
    private var hiddenApps: [String: NSRunningApplication] = [:]  // bundle ID → app

    init(
        blockedBundleIDs: [String],
        frictionDelays: [Int],
        frictionOverlay: FrictionOverlayController,
        overrideLogger: OverrideLogger
    ) {
        self.blockedBundleIDs = Set(blockedBundleIDs)
        self.frictionDelays = frictionDelays
        self.frictionOverlay = frictionOverlay
        self.overrideLogger = overrideLogger
    }

    func startMonitoring(phase: Phase) {
        currentPhase = phase
        temporarilyAllowed.removeAll()

        if !isMonitoring {
            isMonitoring = true
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(appDidLaunch(_:)),
                name: NSWorkspace.didLaunchApplicationNotification,
                object: nil
            )

            // Polling fallback every 2 seconds
            pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.scanRunningApps()
            }
            if let timer = pollingTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        currentPhase = .idle
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        pollingTimer?.invalidate()
        pollingTimer = nil
        temporarilyAllowed.removeAll()
    }

    private func isBlocked(_ bundleID: String) -> Bool {
        blockedBundleIDs.contains(bundleID)
    }

    func hideBlockedApps() {
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            guard let bundleID = app.bundleIdentifier, isBlocked(bundleID) else { continue }
            if temporarilyAllowed.contains(bundleID) { continue }
            app.hide()
            hiddenApps[bundleID] = app
        }
    }

    func unhideAll() {
        for (bundleID, app) in hiddenApps {
            if app.isTerminated { continue }
            app.unhide()
            let displayName = app.localizedName ?? bundleID
            print("[LightsOut] Unhid \(displayName)")
        }
        hiddenApps.removeAll()
    }

    func updateConfig(blockedBundleIDs: [String], frictionDelays: [Int]) {
        self.blockedBundleIDs = Set(blockedBundleIDs)
        self.frictionDelays = frictionDelays
    }

    /// Returns the soonest override expiry as a formatted string, or nil if none active.
    func activeOverrideSummary() -> String? {
        guard let soonest = overrideExpiries.min(by: { $0.value < $1.value }) else { return nil }
        let remaining = max(0, Int(soonest.value.timeIntervalSinceNow))
        let m = remaining / 60
        let s = remaining % 60
        // Show display name if possible
        let displayName = hiddenApps[soonest.key]?.localizedName
            ?? NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == soonest.key })?.localizedName
            ?? soonest.key
        if overrideExpiries.count == 1 {
            return "\(displayName) \(m):\(String(format: "%02d", s))"
        }
        return "\(overrideExpiries.count) overrides \(m):\(String(format: "%02d", s))"
    }

    func resetOverrideCounts() {
        overrideCounts.removeAll()
        temporarilyAllowed.removeAll()
        for (_, timer) in overrideTimers { timer.invalidate() }
        overrideTimers.removeAll()
        overrideExpiries.removeAll()
    }

    // MARK: - Private

    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier,
              isBlocked(bundleID),
              !temporarilyAllowed.contains(bundleID)
        else { return }
        handleBlockedApp(bundleID: bundleID, app: app)
    }

    private func scanRunningApps() {
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            guard let bundleID = app.bundleIdentifier, isBlocked(bundleID) else { continue }
            if temporarilyAllowed.contains(bundleID) { continue }
            if app.isHidden { continue }
            handleBlockedApp(bundleID: bundleID, app: app)
        }
    }

    private func handleBlockedApp(bundleID: String, app: NSRunningApplication) {
        guard isBlocked(bundleID), !temporarilyAllowed.contains(bundleID) else { return }
        let displayName = app.localizedName ?? bundleID

        if currentPhase == .lightsOut {
            // Hide and show blocked overlay with emergency valve
            app.hide()
            hiddenApps[bundleID] = app
            overrideLogger.log(appName: displayName, phase: "lightsOut", frictionDelay: 0)
            frictionOverlay.showBlocked(appName: displayName) { [weak self] in
                guard let self else { return }
                self.temporarilyAllowed.insert(bundleID)
                self.overrideLogger.log(appName: displayName, phase: "lightsOut-emergency", frictionDelay: -2)
                app.unhide()
                self.hiddenApps.removeValue(forKey: bundleID)

                // Emergency overrides are always 5 minutes
                let expiry = Date().addingTimeInterval(5 * 60)
                self.overrideExpiries[bundleID] = expiry
                self.overrideTimers[bundleID]?.invalidate()
                self.overrideTimers[bundleID] = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.temporarilyAllowed.remove(bundleID)
                    self.overrideTimers.removeValue(forKey: bundleID)
                    self.overrideExpiries.removeValue(forKey: bundleID)
                    print("[LightsOut] Emergency override expired for \(displayName)")
                    self.scanRunningApps()
                }
            }
            return
        }

        // Wind-down phase: show friction overlay
        let count = overrideCounts[bundleID, default: 0]

        if count >= frictionDelays.count {
            // Exceeded max overrides — hide completely
            app.hide()
            hiddenApps[bundleID] = app
            overrideLogger.log(appName: displayName, phase: "windDown", frictionDelay: -1)
            frictionOverlay.showBlocked(appName: displayName)
            return
        }

        // Hide the app first, then show friction
        app.hide()
        hiddenApps[bundleID] = app

        let delay = frictionDelays[count]

        guard !frictionOverlay.isShowing else { return }

        frictionOverlay.show(delay: delay, appName: displayName) { [weak self] chosenMinutes in
            guard let self, let minutes = chosenMinutes else { return }
            self.overrideCounts[bundleID, default: 0] += 1
            self.temporarilyAllowed.insert(bundleID)
            self.overrideLogger.log(appName: displayName, phase: "windDown", frictionDelay: delay)
            // Unhide the app for the user
            app.unhide()
            self.hiddenApps.removeValue(forKey: bundleID)

            // Schedule revocation after the chosen duration
            let expiry = Date().addingTimeInterval(TimeInterval(minutes * 60))
            self.overrideExpiries[bundleID] = expiry
            self.overrideTimers[bundleID]?.invalidate()
            self.overrideTimers[bundleID] = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                guard let self else { return }
                self.temporarilyAllowed.remove(bundleID)
                self.overrideTimers.removeValue(forKey: bundleID)
                self.overrideExpiries.removeValue(forKey: bundleID)
                print("[LightsOut] Override expired for \(displayName) after \(minutes) min")
                self.scanRunningApps()
            }
        }
    }
}
