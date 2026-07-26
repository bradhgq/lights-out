import DeviceActivity
import Foundation
import LightsOutCore

/// The `DeviceActivityMonitorExtension` the system invokes at phase boundaries.
///
/// We register three schedules (`amber`, `windDown`, `lightsOut`), each spanning from
/// its phase's start time to morning reset. The system calls:
///   - `intervalDidStart(for:)` when each phase begins → apply that phase's shield.
///   - `intervalDidEnd(for:)` for each phase at morning reset → clear that phase's
///     store. Because all three end at the same morning-reset time, this is how the
///     morning cleanup happens.
///
/// The extension runs in its own process with tight restrictions: no UI, no URL
/// opening, no networking. It can only share state with the main app via the App
/// Group. ManagedSettings shields are the actual mechanism that blocks apps — they
/// persist until we explicitly clear them, independent of whether this extension is
/// alive.
///
/// Grayscale toggling is *not* handled here. iOS doesn't allow monitor extensions to
/// invoke Shortcuts URLs. Instead the user creates a Personal Automation in Shortcuts
/// (see the onboarding wizard) that fires at the phase time on its own. The
/// `LightsOutApp` target runs the shortcut on manual triggers only.
final class LightsOutMonitor: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let phase = PhaseScheduleName.phase(for: activity) else {
            NSLog("[LightsOutMonitor] Unknown activity started: \(activity.rawValue)")
            return
        }

        NSLog("[LightsOutMonitor] intervalDidStart: \(activity.rawValue) → applying \(phase)")
        PhaseApplier.apply(phase: phase)

        // A boundary is the one moment we're guaranteed to run, so it's also where we
        // clean up overrides that lapsed while the app was dead.
        OverrideStore.reconcile()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard let phase = PhaseScheduleName.phase(for: activity) else { return }

        NSLog("[LightsOutMonitor] intervalDidEnd: \(activity.rawValue) → clearing \(phase)")
        PhaseApplier.clear(phase: phase)

        // When the lightsOut interval ends (at morning reset), formally enter idle.
        // The amber and windDown end events also fire at this time; they're harmless
        // no-ops since idle will get set at least once.
        if phase == .lightsOut {
            // Drop override bookkeeping at the same time. A leftover expiry would let
            // reconcile() re-shield during the day, and the nightly counter has to
            // reset or tomorrow's first override inherits tonight's escalation.
            OverrideStore.clearAll()
            OverrideStore.resetNightlyCounter()
            PhaseState.current = .idle
        }
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        // Unused — reserved for future usage-threshold gating (e.g. "shield TikTok
        // after 30 minutes during amber").
        super.eventDidReachThreshold(event, activity: activity)
    }
}
