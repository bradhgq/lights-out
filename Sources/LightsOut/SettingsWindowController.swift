import AppKit
import SwiftUI

class SettingsWindowController {
    private var window: NSWindow?
    private let configManager: ConfigManager
    var onConfigChanged: (() -> Void)?

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(
            configManager: configManager,
            onSave: { [weak self] in
                self?.onConfigChanged?()
                self?.dismiss()
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Lights Out Settings"
        win.contentView = NSHostingView(rootView: view)
        win.contentMinSize = NSSize(width: 480, height: 500)
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)

        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = win
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}
