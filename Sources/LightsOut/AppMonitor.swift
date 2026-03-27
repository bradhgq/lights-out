import AppKit
import Foundation
import LightsOutCore

class AppMonitor {
    /// Lowercased blocked app names for case-insensitive matching
    private var blockedApps: Set<String>
    private var frictionDelays: [Int]
    private let frictionOverlay: FrictionOverlayController
    private let overrideLogger: OverrideLogger

    private var overrideCounts: [String: Int] = [:]
    private var currentPhase: Phase = .idle
    private var isMonitoring = false
    private var pollingTimer: Timer?
    private var temporarilyAllowed: Set<String> = []
    private var overrideTimers: [String: Timer] = [:]
    private(set) var overrideExpiries: [String: Date] = [:]
    private var hiddenApps: [String: NSRunningApplication] = [:]

    init(
        blockedApps: [String],
        frictionDelays: [Int],
        frictionOverlay: FrictionOverlayController,
        overrideLogger: OverrideLogger
    ) {
        self.blockedApps = Set(blockedApps.map { $0.lowercased() })
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

    private func isBlocked(_ name: String) -> Bool {
        blockedApps.contains(name.lowercased())
    }

    func hideBlockedApps() {
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            guard let name = app.localizedName, isBlocked(name) else { continue }
            if temporarilyAllowed.contains(name) { continue }
            app.hide()
            hiddenApps[name] = app
        }
    }

    func unhideAll() {
        for (name, app) in hiddenApps {
            if app.isTerminated { continue }
            app.unhide()
            print("[LightsOut] Unhid \(name)")
        }
        hiddenApps.removeAll()
    }

    func updateConfig(blockedApps: [String], frictionDelays: [Int]) {
        self.blockedApps = Set(blockedApps.map { $0.lowercased() })
        self.frictionDelays = frictionDelays
    }

    /// Returns the soonest override expiry as a formatted string, or nil if none active.
    func activeOverrideSummary() -> String? {
        guard let soonest = overrideExpiries.min(by: { $0.value < $1.value }) else { return nil }
        let remaining = max(0, Int(soonest.value.timeIntervalSinceNow))
        let m = remaining / 60
        let s = remaining % 60
        if overrideExpiries.count == 1 {
            return "\(soonest.key) \(m):\(String(format: "%02d", s))"
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
              let name = app.localizedName,
              isBlocked(name),
              !temporarilyAllowed.contains(name)
        else { return }
        handleBlockedApp(name: name, app: app)
    }

    private func scanRunningApps() {
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            guard let name = app.localizedName, isBlocked(name) else { continue }
            if temporarilyAllowed.contains(name) { continue }
            if app.isHidden { continue }
            handleBlockedApp(name: name, app: app)
        }
    }

    private func handleBlockedApp(name: String, app: NSRunningApplication) {
        guard isBlocked(name), !temporarilyAllowed.contains(name) else { return }

        if currentPhase == .lightsOut {
            // Hide and show blocked overlay with emergency valve
            app.hide()
            hiddenApps[name] = app
            overrideLogger.log(appName: name, phase: "lightsOut", frictionDelay: 0)
            frictionOverlay.showBlocked(appName: name) { [weak self] in
                guard let self else { return }
                self.temporarilyAllowed.insert(name)
                self.overrideLogger.log(appName: name, phase: "lightsOut-emergency", frictionDelay: -2)
                app.unhide()
                self.hiddenApps.removeValue(forKey: name)

                // Emergency overrides are always 5 minutes
                let expiry = Date().addingTimeInterval(5 * 60)
                self.overrideExpiries[name] = expiry
                self.overrideTimers[name]?.invalidate()
                self.overrideTimers[name] = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.temporarilyAllowed.remove(name)
                    self.overrideTimers.removeValue(forKey: name)
                    self.overrideExpiries.removeValue(forKey: name)
                    print("[LightsOut] Emergency override expired for \(name)")
                }
            }
            return
        }

        // Wind-down phase: show friction overlay
        let count = overrideCounts[name, default: 0]

        if count >= frictionDelays.count {
            // Exceeded max overrides — hide completely
            app.hide()
            hiddenApps[name] = app
            overrideLogger.log(appName: name, phase: "windDown", frictionDelay: -1)
            frictionOverlay.showBlocked(appName: name)
            return
        }

        // Hide the app first, then show friction
        app.hide()
        hiddenApps[name] = app

        let delay = frictionDelays[count]

        guard !frictionOverlay.isShowing else { return }

        frictionOverlay.show(delay: delay, appName: name) { [weak self] chosenMinutes in
            guard let self, let minutes = chosenMinutes else { return }
            self.overrideCounts[name, default: 0] += 1
            self.temporarilyAllowed.insert(name)
            self.overrideLogger.log(appName: name, phase: "windDown", frictionDelay: delay)
            // Unhide the app for the user
            app.unhide()
            self.hiddenApps.removeValue(forKey: name)

            // Schedule revocation after the chosen duration
            let expiry = Date().addingTimeInterval(TimeInterval(minutes * 60))
            self.overrideExpiries[name] = expiry
            self.overrideTimers[name]?.invalidate()
            self.overrideTimers[name] = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                guard let self else { return }
                self.temporarilyAllowed.remove(name)
                self.overrideTimers.removeValue(forKey: name)
                self.overrideExpiries.removeValue(forKey: name)
                print("[LightsOut] Override expired for \(name) after \(minutes) min")
            }
        }
    }
}
