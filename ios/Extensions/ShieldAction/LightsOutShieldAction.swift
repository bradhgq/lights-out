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

            if let url = URL(string: "lightsout://override?store=\(storeName)") {
                // ShieldActionDelegate has no direct URL-open API; the system will
                // surface the main app in response to `.defer` combined with the
                // user having already tapped the shield. In practice, we rely on
                // the user opening the app manually; the store name is retrievable
                // from PhaseState.current on launch.
                //
                // Future refinement: register a custom URL scheme in Info.plist and
                // use `extensionContext?.open(_:completionHandler:)` where permitted.
                _ = url
            }

            // Stash the pending override so the app can read it on next foreground.
            AppGroup.userDefaults.set(storeName, forKey: "lightsout.pendingOverride")

            completionHandler(.defer)

        case .secondaryButtonPressed:
            // "Go to bed" — dismiss the shield (same-session only; the phase is still
            // active, so the shield will re-appear on the next app launch attempt).
            completionHandler(.defer)

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
