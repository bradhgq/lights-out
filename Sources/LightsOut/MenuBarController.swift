import AppKit
import LightsOutCore
import SwiftUI

class MenuBarController: NSObject, NSMenuItemValidation {
    private let statusItem: NSStatusItem
    private let phaseManager: PhaseManager
    private let checklistManager: ChecklistManager
    private var checklistMenuItems: [NSMenuItem] = []
    var showCountdownInMenuBar = true
    var onOpenSettings: (() -> Void)?

    init(phaseManager: PhaseManager, checklistManager: ChecklistManager) {
        self.phaseManager = phaseManager
        self.checklistManager = checklistManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupMenu()
        updatePhase(.idle)
    }

    /// AppKit calls this for each menu item before display — this is what actually controls greying out
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.tag == 400 || menuItem.tag == 401 {
            return phaseManager.currentPhase == .idle || phaseManager.devMode
        }
        return true
    }

    func updatePhase(_ phase: Phase) {
        guard let button = statusItem.button else { return }
        switch phase {
        case .idle:
            button.image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "Lights Out")
        case .amber:
            button.image = NSImage(systemSymbolName: "moon.haze.fill", accessibilityDescription: "Amber")
        case .windDown:
            button.image = NSImage(systemSymbolName: "moon.dust.fill", accessibilityDescription: "Wind Down")
        case .lightsOut:
            button.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Lights Out")
        }

        // Update phase label in menu
        let phaseName: String
        switch phase {
        case .idle: phaseName = "Idle"
        case .amber: phaseName = "Amber"
        case .windDown: phaseName = "Wind Down"
        case .lightsOut: phaseName = "Lights Out"
        }
        statusItem.menu?.items.first(where: { $0.tag == 50 })?.title = "Phase: \(phaseName)"
    }

    func updateCountdown(_ text: String) {
        // Always show in dropdown menu
        statusItem.menu?.items.first(where: { $0.tag == 51 })?.title = text
        // Optionally also show in menubar
        statusItem.button?.title = showCountdownInMenuBar ? " \(text)" : ""
    }

    func refreshChecklist() {
        let items = checklistManager.items
        // Remove old checklist items
        for item in checklistMenuItems {
            statusItem.menu?.removeItem(item)
        }
        checklistMenuItems.removeAll()

        guard let menu = statusItem.menu,
              let separatorIndex = menu.items.firstIndex(where: { $0.tag == 100 })
        else { return }

        // Insert checklist items after the separator with tag 100
        for (index, checkItem) in items.enumerated() {
            let menuItem = NSMenuItem(
                title: checkItem.title,
                action: #selector(toggleChecklistItem(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.tag = 200 + index
            menuItem.state = checkItem.completed ? .on : .off
            menu.insertItem(menuItem, at: separatorIndex + 1 + index)
            checklistMenuItems.append(menuItem)
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let phaseItem = NSMenuItem(title: "Phase: Idle", action: nil, keyEquivalent: "")
        phaseItem.tag = 50
        phaseItem.isEnabled = false
        menu.addItem(phaseItem)

        let countdownItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        countdownItem.tag = 51
        countdownItem.isEnabled = false
        menu.addItem(countdownItem)

        menu.addItem(NSMenuItem.separator())

        let checklistHeader = NSMenuItem(title: "Checklist", action: nil, keyEquivalent: "")
        checklistHeader.isEnabled = false
        menu.addItem(checklistHeader)

        let checklistSep = NSMenuItem.separator()
        checklistSep.tag = 100
        menu.addItem(checklistSep)

        // Checklist items will be inserted here by refreshChecklist()

        menu.addItem(NSMenuItem.separator())

        #if DEV_MODE
        // Dev Mode submenu
        let devMenu = NSMenu(title: "Dev Mode")

        let devToggle = NSMenuItem(title: "Enable Dev Mode", action: #selector(toggleDevMode(_:)), keyEquivalent: "d")
        devToggle.target = self
        devToggle.tag = 300
        devMenu.addItem(devToggle)

        devMenu.addItem(NSMenuItem.separator())

        let phases: [(String, Phase, String)] = [
            ("Idle", .idle, "1"),
            ("Amber", .amber, "2"),
            ("Wind-Down", .windDown, "3"),
            ("Lights Out", .lightsOut, "4"),
        ]
        for (index, (title, _, key)) in phases.enumerated() {
            let item = NSMenuItem(title: "→ \(title)", action: #selector(devForcePhase(_:)), keyEquivalent: key)
            item.target = self
            item.tag = 310 + index
            item.isEnabled = false
            devMenu.addItem(item)
        }

        let devMenuItem = NSMenuItem(title: "Dev Mode", action: nil, keyEquivalent: "")
        devMenuItem.submenu = devMenu
        menu.addItem(devMenuItem)

        menu.addItem(NSMenuItem.separator())
        #endif

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.tag = 400
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit Lights Out",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.tag = 401
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshChecklist()
    }

    #if DEV_MODE
    private static let devPhases: [Phase] = [.idle, .amber, .windDown, .lightsOut]

    @objc private func toggleDevMode(_ sender: NSMenuItem) {
        let enabling = !phaseManager.devMode
        phaseManager.setDevMode(enabling)
        sender.title = enabling ? "✓ Dev Mode On" : "Enable Dev Mode"

        // Enable/disable phase buttons
        guard let devMenu = sender.menu else { return }
        for item in devMenu.items {
            if item.tag >= 310 && item.tag <= 313 {
                item.isEnabled = enabling
            }
        }
    }

    @objc private func devForcePhase(_ sender: NSMenuItem) {
        let index = sender.tag - 310
        guard index >= 0 && index < Self.devPhases.count else { return }
        phaseManager.forcePhase(Self.devPhases[index])
    }

    #endif

    @objc private func toggleChecklistItem(_ sender: NSMenuItem) {
        let index = sender.tag - 200
        checklistManager.toggle(at: index)
        sender.state = checklistManager.items[index].completed ? .on : .off
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
