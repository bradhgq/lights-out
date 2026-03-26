import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var configManager: ConfigManager!
    private var phaseManager: PhaseManager!
    private var menuBarController: MenuBarController!
    private var appMonitor: AppMonitor!
    private var hostFileManager: HostFileManager!
    private var displayManager: DisplayManager!
    private var notificationManager: NotificationManager!
    private var checklistManager: ChecklistManager!
    private var overrideLogger: OverrideLogger!
    private var shortcutTrigger: ShortcutTrigger!
    private var frictionOverlay: FrictionOverlayController!
    private var checklistWindow: ChecklistWindowController!

    private var previousPhase: Phase = .idle

    func applicationDidFinishLaunching(_ notification: Notification) {
        HelperInstaller.installIfNeeded()

        configManager = ConfigManager()
        let config = configManager.config

        overrideLogger = OverrideLogger()
        checklistManager = ChecklistManager(items: config.checklist)
        displayManager = DisplayManager()
        hostFileManager = HostFileManager()
        notificationManager = NotificationManager()
        shortcutTrigger = ShortcutTrigger()
        frictionOverlay = FrictionOverlayController()

        appMonitor = AppMonitor(
            blockedApps: config.blockedApps,
            whitelistedApps: config.whitelistedApps,
            frictionDelays: config.frictionDelaysSeconds,
            frictionOverlay: frictionOverlay,
            overrideLogger: overrideLogger
        )

        checklistWindow = ChecklistWindowController(checklistManager: checklistManager)
        checklistWindow.onChecklistChanged = { [weak self] in
            self?.menuBarController.refreshChecklist()
        }

        phaseManager = PhaseManager(config: config)
        phaseManager.delegate = self

        menuBarController = MenuBarController(
            phaseManager: phaseManager,
            checklistManager: checklistManager
        )

        // Swallow Cmd+Q when not idle
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                #if DEV_MODE
                if self.phaseManager.devMode { return event }
                #endif
                if self.phaseManager.currentPhase != .idle {
                    return nil
                }
            }
            return event
        }

        configManager.onConfigReloaded = { [weak self] in
            self?.handleConfigReload()
        }

        notificationManager.requestPermission()
        phaseManager.start()
    }
}

extension AppDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        #if DEV_MODE
        if phaseManager.devMode { return .terminateNow }
        #endif
        if phaseManager.currentPhase != .idle {
            return .terminateCancel
        }
        return .terminateNow
    }
}

// MARK: - Declarative Phase Behaviors

/// Each phase defines its desired state. When entering a phase, we apply
/// everything it needs regardless of which phase we came from.
private struct PhaseBehavior {
    let warmGamma: Bool
    let dimBrightness: Bool
    let blockDomains: Bool
    let monitorApps: Bool      // hide blocked apps
    let showChecklist: Bool
    let sendNotification: Bool
    let triggerShortcut: Bool
}

private let phaseBehaviors: [Phase: PhaseBehavior] = [
    .idle: PhaseBehavior(
        warmGamma: false, dimBrightness: false, blockDomains: false,
        monitorApps: false, showChecklist: false, sendNotification: false,
        triggerShortcut: false
    ),
    .amber: PhaseBehavior(
        warmGamma: true, dimBrightness: false, blockDomains: false,
        monitorApps: false, showChecklist: true, sendNotification: true,
        triggerShortcut: false
    ),
    .windDown: PhaseBehavior(
        warmGamma: true, dimBrightness: false, blockDomains: true,
        monitorApps: true, showChecklist: true, sendNotification: true,
        triggerShortcut: false
    ),
    .lightsOut: PhaseBehavior(
        warmGamma: true, dimBrightness: true, blockDomains: true,
        monitorApps: true, showChecklist: true, sendNotification: true,
        triggerShortcut: true
    ),
]

extension AppDelegate: PhaseManagerDelegate {
    func phaseDidChange(to phase: Phase) {
        let config = configManager.config
        let behavior = phaseBehaviors[phase]!
        let prev = phaseBehaviors[previousPhase]!

        menuBarController.updatePhase(phase)

        // --- Display ---
        if behavior.warmGamma && !prev.warmGamma {
            displayManager.setWarmGamma()
        } else if !behavior.warmGamma && prev.warmGamma {
            displayManager.resetGamma()
        }

        if behavior.dimBrightness && !prev.dimBrightness {
            displayManager.setMinimumBrightness()
        } else if !behavior.dimBrightness && prev.dimBrightness {
            displayManager.restoreBrightness()
        }

        // --- Domain blocking ---
        if behavior.blockDomains && !prev.blockDomains {
            hostFileManager.blockDomains(config.blockedDomains)
        } else if !behavior.blockDomains && prev.blockDomains {
            hostFileManager.unblockDomains()
        }

        // --- App monitoring ---
        if behavior.monitorApps {
            appMonitor.startMonitoring(phase: phase)
            appMonitor.hideBlockedApps()
        } else if !behavior.monitorApps && prev.monitorApps {
            appMonitor.stopMonitoring()
            appMonitor.unhideAll()
        }

        // --- Checklist / notification (only fire on entry, not re-entry) ---
        if behavior.showChecklist && !prev.showChecklist {
            checklistWindow.show()
        }
        if behavior.sendNotification && !prev.sendNotification {
            notificationManager.postAmberNotification(checklist: config.checklist)
        }
        if !behavior.showChecklist && prev.showChecklist {
            checklistWindow.dismiss()
        }

        // --- Shortcut (fire once on entry to lightsOut) ---
        if behavior.triggerShortcut && !prev.triggerShortcut && config.enableShortcutTrigger {
            shortcutTrigger.run(shortcutName: config.shortcutName)
        }

        // --- Reset on idle ---
        if phase == .idle {
            checklistManager.reset(items: config.checklist)
            appMonitor.resetOverrideCounts()
            displayManager.restoreAll()
        }

        previousPhase = phase
    }

    func countdownDidUpdate(_ text: String) {
        if let overrideSummary = appMonitor.activeOverrideSummary() {
            menuBarController.updateCountdown("\(text) | \(overrideSummary)")
        } else {
            menuBarController.updateCountdown(text)
        }
    }

    func morningResetTriggered() {
        phaseDidChange(to: .idle)
    }

    private func handleConfigReload() {
        let config = configManager.config
        phaseManager.updateConfig(config)
        appMonitor.updateConfig(
            blockedApps: config.blockedApps,
            whitelistedApps: config.whitelistedApps,
            frictionDelays: config.frictionDelaysSeconds
        )
        checklistManager.reset(items: config.checklist)
        menuBarController.refreshChecklist()
        print("[LightsOut] Config applied")
    }
}
