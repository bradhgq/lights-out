import Foundation
import ManagedSettings
import FamilyControls
import LightsOutCore

/// Applies or clears `ManagedSettings` restrictions for a given phase.
///
/// Called from the `DeviceActivityMonitorExtension` at phase boundaries. Kept in
/// shared code (not the extension target) so the main app can call it directly for
/// the "Enter Lights Out now" manual trigger.
///
/// Design note: the three phase stores (`phase.amber`, `phase.windDown`, `phase.lightsOut`)
/// persist independently. Each `apply` call replaces its store's restrictions wholesale,
/// and `clear` empties that store. The system unions all active stores when deciding
/// what to shield, so you get natural layering without extra coordination.
public enum PhaseApplier {

    /// Apply the shield for `phase` using the currently-selected apps/categories/domains.
    /// A no-op if `phase == .idle` (idle has no store).
    public static func apply(phase: Phase) {
        guard let storeName = PhaseStoreName.name(for: phase) else {
            // idle → nothing to apply. Defensive: some call sites pass .idle.
            return
        }

        let selection = ActivitySelectionStore.load()
        let store = ManagedSettingsStore(named: .init(storeName))

        // Strategy per phase:
        //   amber:     shield web domains only — a soft nudge.
        //   windDown:  shield web domains + selected app categories.
        //   lightsOut: shield everything the user picked.
        //
        // This escalation matches the macOS overlay's behavior: amber is a reminder,
        // wind-down adds friction, lights-out is near-total.
        switch phase {
        case .amber:
            store.shield.webDomains = selection.webDomainTokens.isEmpty
                ? nil : selection.webDomainTokens
            store.shield.applications = nil
            store.shield.applicationCategories = nil
        case .windDown:
            store.shield.webDomains = selection.webDomainTokens.isEmpty
                ? nil : selection.webDomainTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil
                : .specific(selection.categoryTokens, except: Set())
            store.shield.applications = nil
        case .lightsOut:
            store.shield.applications = selection.applicationTokens.isEmpty
                ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil
                : .specific(selection.categoryTokens, except: Set())
            store.shield.webDomains = selection.webDomainTokens.isEmpty
                ? nil : selection.webDomainTokens
        case .idle:
            break
        }

        PhaseState.current = phase
    }

    /// Clear a single phase's store. Safe to call when the store was never applied.
    public static func clear(phase: Phase) {
        guard let storeName = PhaseStoreName.name(for: phase) else { return }
        let store = ManagedSettingsStore(named: .init(storeName))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    /// Clear all phase stores. Used at morning reset, and when the user disables the
    /// app or revokes authorization.
    ///
    /// Also drops override bookkeeping: expiries left behind here would otherwise
    /// re-apply a shield during the day, and the nightly counter has to reset or
    /// tomorrow's first override would inherit tonight's escalation.
    public static func clearAll() {
        for phase in [Phase.amber, .windDown, .lightsOut] {
            clear(phase: phase)
        }
        OverrideStore.clearAll()
        OverrideStore.resetNightlyCounter()
        PhaseState.current = .idle
    }
}
