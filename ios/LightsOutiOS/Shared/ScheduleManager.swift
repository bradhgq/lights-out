import Foundation
import DeviceActivity
import LightsOutCore

/// Register / unregister the three phase schedules with `DeviceActivityCenter`.
///
/// This is called:
/// - Once the user grants Screen Time authorization.
/// - Whenever the user changes phase times or selected apps in settings.
/// - When the user toggles the overall "enabled" switch.
///
/// The DeviceActivityCenter persists schedules across launches; we always
/// `stopMonitoring` + `startMonitoring` to replace whatever was registered before,
/// so stale schedules from an older config can't linger.
public enum ScheduleManager {

    /// Re-register all three phase schedules for the current config. No-op if the
    /// config times don't parse (shouldn't happen after `validate()`).
    ///
    /// Deliberately does *not* go through `stop()`: that clears every shield. Saving
    /// settings at 23:45 would therefore drop the user's active blocks and mark the
    /// phase idle, and recovery depended on `intervalDidStart` firing again for an
    /// interval already in progress — which it does not. Instead we re-register the
    /// schedules and immediately re-assert whatever should be in force right now.
    public static func reschedule(using config: LightsOutConfig) {
        guard let schedules = PhaseScheduleBuilder.buildSchedules(from: config) else {
            NSLog("[LightsOut] Could not build schedules from config; skipping")
            return
        }

        let center = DeviceActivityCenter()
        center.stopMonitoring(PhaseScheduleName.all)

        for (name, schedule) in schedules {
            do {
                try center.startMonitoring(name, during: schedule)
            } catch {
                NSLog("[LightsOut] Failed to start monitoring \(name.rawValue): \(error)")
            }
        }

        reassertCurrentPhase(using: config)
    }

    /// Re-apply the shields that should be active at this moment, honouring any
    /// override still running. Phases layer, so every phase up to the current one is
    /// re-applied, not just the newest.
    private static func reassertCurrentPhase(using config: LightsOutConfig) {
        let current = computePhase(config: config.timelineConfig, at: Date())

        guard current != .idle else {
            PhaseApplier.clearAll()
            return
        }

        for phase in [Phase.amber, .windDown, .lightsOut] where phase.isInForce(whenCurrentIs: current) {
            // Don't stomp on an override the user is currently serving out.
            guard !OverrideStore.isOverridden(phase) else { continue }
            PhaseApplier.apply(phase: phase)
        }
    }

    /// Stop monitoring all three phase schedules and clear any shields.
    /// Used when the user disables the feature or revokes authorization.
    public static func stop() {
        let center = DeviceActivityCenter()
        center.stopMonitoring(PhaseScheduleName.all)
        PhaseApplier.clearAll()
    }
}
