import Foundation
import LightsOutCore

/// Tracks granted overrides in the App Group, so they survive the app dying.
///
/// The friction sheet lifts a phase's shield by clearing its `ManagedSettingsStore`,
/// then needs to put it back when the override expires. Holding that solely as an
/// in-process timer makes the block trivially defeatable: grant a 5-minute override,
/// force-quit, and nothing ever re-applies the shield until the next phase boundary
/// (potentially not until tomorrow night).
///
/// So the expiry is persisted, and `reconcile()` restores anything overdue. It runs on
/// every foreground and at each phase boundary in the monitor extension. The in-process
/// timer stays as the fast path for when the app is actually alive.
///
/// Residual gap worth knowing: nothing can run *while* the app is dead. If the user
/// force-quits and never reopens Lights Out, the shield stays lifted until the monitor
/// extension's next `intervalDidStart`. Closing that fully would need the override to be
/// expressed as a scheduled DeviceActivity interval rather than a cleared store.
public enum OverrideStore {

    // MARK: - Granting

    /// Record and apply an override for `phase` lasting `minutes`.
    public static func grant(phase: Phase, minutes: Int, now: Date = Date()) {
        guard let storeName = PhaseStoreName.name(for: phase) else { return }

        let expiry = now.addingTimeInterval(TimeInterval(minutes * 60))
        AppGroup.userDefaults.set(expiry, forKey: AppGroupKey.overrideExpiry(for: storeName))
        AppGroup.userDefaults.set(grantedTonight + 1, forKey: AppGroupKey.overrideCount)

        PhaseApplier.clear(phase: phase)
    }

    /// Expiry of the active override for `phase`, if any.
    public static func expiry(for phase: Phase) -> Date? {
        guard let storeName = PhaseStoreName.name(for: phase) else { return nil }
        return AppGroup.userDefaults
            .object(forKey: AppGroupKey.overrideExpiry(for: storeName)) as? Date
    }

    /// Whether `phase` currently has an override lifting its shield.
    public static func isOverridden(_ phase: Phase, at now: Date = Date()) -> Bool {
        guard let expiry = expiry(for: phase) else { return false }
        return now < expiry
    }

    // MARK: - Nightly counter

    /// How many overrides have been granted since the last morning reset. Drives
    /// escalation via `FrictionEscalation`.
    public static var grantedTonight: Int {
        AppGroup.userDefaults.integer(forKey: AppGroupKey.overrideCount)
    }

    /// Reset the nightly counter. Called from `PhaseApplier.clearAll()`, which runs at
    /// morning reset — so "tonight" means "since the last time everything cleared".
    public static func resetNightlyCounter() {
        AppGroup.userDefaults.removeObject(forKey: AppGroupKey.overrideCount)
    }

    // MARK: - Reconciliation

    /// Re-apply shields for any override that has expired, and drop its record.
    ///
    /// Only restores phases still in force at `now` — if the user slept through morning
    /// reset, the override is stale and re-applying would shield them during the day.
    /// - Returns: the phases whose shields were restored.
    @discardableResult
    public static func reconcile(at now: Date = Date()) -> [Phase] {
        let current = PhaseState.computedPhase(at: now)
        var restored: [Phase] = []

        for phase in [Phase.amber, .windDown, .lightsOut] {
            guard let storeName = PhaseStoreName.name(for: phase),
                  let expiry = AppGroup.userDefaults
                      .object(forKey: AppGroupKey.overrideExpiry(for: storeName)) as? Date
            else { continue }

            guard now >= expiry else { continue }   // still within the granted window

            AppGroup.userDefaults.removeObject(forKey: AppGroupKey.overrideExpiry(for: storeName))

            if phase.isInForce(whenCurrentIs: current) {
                PhaseApplier.apply(phase: phase)
                restored.append(phase)
            }
        }

        return restored
    }

    /// Drop every override record without touching shields. Used when clearing all
    /// state (morning reset, disable) so stale expiries can't resurrect later.
    public static func clearAll() {
        for phase in [Phase.amber, .windDown, .lightsOut] {
            guard let storeName = PhaseStoreName.name(for: phase) else { continue }
            AppGroup.userDefaults.removeObject(forKey: AppGroupKey.overrideExpiry(for: storeName))
        }
    }
}
