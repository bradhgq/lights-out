import SwiftUI

/// Main SwiftUI app entry.
///
/// The app is deliberately single-window: no TabView. Most of the time a user opens
/// the app briefly to check the countdown or change settings; the primary view is
/// `PhaseDashboardView`. Onboarding runs automatically on first launch (detected by
/// absence of any stored config).
@main
struct LightsOutApp: App {
    @StateObject private var authorization = AuthorizationManager()
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authorization)
                .environmentObject(appState)
                .onOpenURL { url in
                    // Shield action extensions can open us with lightsout://override?…
                    // to trigger the friction flow for a specific app.
                    appState.handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // A shield-action extension may have flagged a pending
                        // override while we were backgrounded — re-check.
                        appState.refreshPendingOverride()
                        authorization.refresh()
                        // Restore any shield whose override lapsed while we weren't
                        // running. Without this, force-quitting during an override
                        // leaves the block off until the next phase boundary.
                        OverrideStore.reconcile()
                    }
                }
        }
    }
}

/// Top-level state shared across views. Holds the pending override (if a shield action
/// just launched us) and flags that control which sheet is presented.
@MainActor
final class AppState: ObservableObject {

    /// When a shield-action extension flagged a pending override, this holds the
    /// phase store name (e.g. "phase.lightsOut") for the friction sheet to target.
    @Published var pendingOverridePhase: String?

    /// Whether the onboarding flow should be shown. Computed at init from whether
    /// a config has ever been saved; can be forced true by "reset onboarding" in
    /// settings.
    @Published var needsOnboarding: Bool

    init() {
        self.needsOnboarding = !ConfigStore.hasStoredConfig
        self.pendingOverridePhase = AppGroup.userDefaults
            .string(forKey: AppGroupKey.pendingOverride)
    }

    /// Handle `lightsout://override?store=<phase>` URLs from the shield-action ext.
    /// (Back-up path — the primary signal is the App Group UserDefaults key.)
    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "lightsout", url.host == "override" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let store = components?.queryItems?.first(where: { $0.name == "store" })?.value {
            pendingOverridePhase = store
        }
    }

    /// Re-read the App Group pending-override key. Called on foreground transitions
    /// by the scene lifecycle — the shield action writes this key and doesn't wake
    /// the app directly, so we notice on next launch.
    func refreshPendingOverride() {
        pendingOverridePhase = AppGroup.userDefaults.string(forKey: AppGroupKey.pendingOverride)
    }

    /// Clear the pending override (after the sheet is dismissed or completed).
    func clearPendingOverride() {
        pendingOverridePhase = nil
        AppGroup.userDefaults.removeObject(forKey: AppGroupKey.pendingOverride)
    }

    /// Force the onboarding flow to run again (exposed in Settings).
    func resetOnboarding() {
        needsOnboarding = true
    }
}
