import SwiftUI
import FamilyControls

/// The app's root content view. Chooses between onboarding and the main dashboard,
/// and hosts the override sheet that the shield-action extension can trigger.
struct RootView: View {
    @EnvironmentObject var authorization: AuthorizationManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.needsOnboarding || authorization.status != .approved {
                OnboardingView()
            } else {
                PhaseDashboardView()
            }
        }
        .sheet(
            isPresented: Binding(
                get: { appState.pendingOverridePhase != nil },
                set: { if !$0 { appState.clearPendingOverride() } }
            )
        ) {
            if let phaseRaw = appState.pendingOverridePhase {
                FrictionOverrideSheet(phaseStoreName: phaseRaw)
            }
        }
        .onAppear { authorization.refresh() }
    }
}
