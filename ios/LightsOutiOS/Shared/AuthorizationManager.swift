import Foundation
import FamilyControls

/// Thin observable wrapper around `AuthorizationCenter` for Screen Time.
///
/// Family Controls requires explicit user authorization per the privacy model: the user
/// must agree (via a system alert) that this app can shield other apps. Until that
/// happens, every ManagedSettings / DeviceActivity API is a silent no-op.
@MainActor
public final class AuthorizationManager: ObservableObject {

    @Published public private(set) var status: AuthorizationStatus

    public init() {
        // `AuthorizationCenter.shared.authorizationStatus` is the current cached state.
        self.status = AuthorizationCenter.shared.authorizationStatus
    }

    /// Request `.individual` authorization — for a personal wellbeing app (as opposed
    /// to family/child restriction). The system alert explains what this grants.
    ///
    /// Safe to call repeatedly; if already authorized, resolves immediately.
    public func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            self.status = AuthorizationCenter.shared.authorizationStatus
        } catch {
            // User denied, already denied, or system refused. Keep status in sync.
            self.status = AuthorizationCenter.shared.authorizationStatus
            NSLog("[LightsOut] requestAuthorization failed: \(error)")
        }
    }

    /// Re-read the status from the system (e.g. on app foreground, in case the user
    /// toggled Screen Time restrictions in Settings while we were backgrounded).
    public func refresh() {
        self.status = AuthorizationCenter.shared.authorizationStatus
    }
}
