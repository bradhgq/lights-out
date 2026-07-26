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
    public static func reschedule(using config: LightsOutConfig) {
        stop()

        guard let schedules = PhaseScheduleBuilder.buildSchedules(from: config) else {
            NSLog("[LightsOut] Could not build schedules from config; skipping")
            return
        }

        let center = DeviceActivityCenter()
        for (name, schedule) in schedules {
            do {
                try center.startMonitoring(name, during: schedule)
            } catch {
                NSLog("[LightsOut] Failed to start monitoring \(name.rawValue): \(error)")
            }
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
