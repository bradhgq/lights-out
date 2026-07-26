import ManagedSettings
import Foundation
import LightsOutCore

/// Handles button taps on shields.
///
/// The system invokes `handle(action:for:completionHandler:)` when the user taps
/// either the primary or secondary button on a shield rendered by our
/// `ShieldConfigurationExtension`. We respond with a `ShieldActionResponse`:
///   - `.defer` — keep the shield up (used for "Go to bed": we do nothing, shield stays)
///   - `.close` — dismiss the shield (used after the override flow completes)
///
/// To drive the friction override, we set a flag in the App Group and ask the system
/// to open the main app via a URL — the app reads the pending flag on launch and
/// presents the friction sheet.
final class LightsOutShieldAction: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    // MARK: - Shared action handler

    private func handle(
        action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // "Request override" / "Continue anyway". Record the current phase in the
            // App Group so the main app can present the right friction UI when it
            // receives the URL below.
            let currentPhase = PhaseState.current
            let storeName = PhaseStoreName.name(for: currentPhase)
                ?? PhaseStoreName.windDown

            // Stash the pending override so the app can read it on next foreground.
            // This — not a URL — is the load-bearing handoff: ShieldActionDelegate
            // has no reliable way to open the containing app, so the user reopens
            // Lights Out manually and the app picks this key up in
            // `AppState.refreshPendingOverride()`. The lightsout:// scheme is now
            // registered as a secondary path for callers that *can* open a URL.
            AppGroup.userDefaults.set(storeName, forKey: AppGroupKey.pendingOverride)

            // Keep the shield up: the override isn't granted until the user completes
            // the friction flow in the app.
            completionHandler(.defer)

        case .secondaryButtonPressed:
            // "Go to bed" — close the shielded app and return the user to the home
            // screen. `.defer` here would leave the shield on screen and make this
            // button indistinguishable from "Request override".
            completionHandler(.close)

        case .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            // Secondary-submenu items, added in the iOS 26 SDK. We never configure a
            // submenu in ShieldConfiguration, so these are unreachable today; keep the
            // shield up rather than silently letting an unhandled tap through.
            completionHandler(.defer)

        @unknown default:
            completionHandler(.defer)
        }
    }
}
