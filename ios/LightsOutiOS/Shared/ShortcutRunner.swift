import Foundation
import UIKit

/// Opens a user-created Shortcut by name via the `shortcuts://` URL scheme.
///
/// iOS provides no public API to toggle system accessibility settings (Color Filters /
/// grayscale), so we delegate to a user-maintained Shortcut. The onboarding wizard
/// walks the user through creating two Shortcuts (one to turn grayscale on, one off)
/// either as personal automations at the phase times or as plain shortcuts we invoke
/// from code.
///
/// `runShortcut(named:)` opens Shortcuts and runs the named shortcut if it exists.
/// If the shortcut doesn't exist, Shortcuts shows an error; we can't detect this
/// from our side because the URL scheme is fire-and-forget.
public enum ShortcutRunner {

    /// Run a Shortcut by name. Returns `true` if iOS accepted the URL (the shortcut
    /// *may still* not exist — we can't know for sure). Returns `false` if the URL
    /// was malformed or couldn't be opened.
    ///
    /// Must be called on the main thread (UIApplication requirement).
    @MainActor
    @discardableResult
    public static func runShortcut(named name: String) -> Bool {
        guard let url = shortcutURL(for: name) else {
            return false
        }
        guard UIApplication.shared.canOpenURL(url) else {
            return false
        }
        UIApplication.shared.open(url)
        return true
    }

    /// Open the Shortcuts app directly (no specific shortcut). Useful for onboarding
    /// when guiding the user to create their first personal automation.
    @MainActor
    @discardableResult
    public static func openShortcutsApp() -> Bool {
        guard let url = URL(string: "shortcuts://") else { return false }
        guard UIApplication.shared.canOpenURL(url) else { return false }
        UIApplication.shared.open(url)
        return true
    }

    /// Build the `shortcuts://run-shortcut?name=...` URL for a given name.
    /// Exposed for testing; `runShortcut(named:)` uses this internally.
    public static func shortcutURL(for name: String) -> URL? {
        // Percent-encode using a conservative character set — shortcut names can
        // contain spaces, em dashes, quotes, etc.
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        return components.url
    }
}
