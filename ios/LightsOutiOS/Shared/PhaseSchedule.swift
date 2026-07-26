import Foundation
import DeviceActivity
import LightsOutCore

/// Names for the three `DeviceActivity` schedules we register, one per active phase.
///
/// Each schedule has its own `ManagedSettingsStore` so phases compose cleanly:
/// amber applies its store at amber-start, windDown applies a stricter store at
/// windDown-start (on top of amber), lightsOut applies the strictest at lightsOut-start,
/// and each `intervalDidEnd` clears only its own store. At morning reset all three
/// intervals have ended and everything is clear.
public enum PhaseScheduleName {
    public static let amber = DeviceActivityName("lightsout.phase.amber")
    public static let windDown = DeviceActivityName("lightsout.phase.windDown")
    public static let lightsOut = DeviceActivityName("lightsout.phase.lightsOut")

    /// All three, for iteration in the monitor extension.
    public static let all: [DeviceActivityName] = [amber, windDown, lightsOut]

    /// Map a schedule name back to its `Phase`.
    public static func phase(for name: DeviceActivityName) -> Phase? {
        switch name {
        case amber:     return .amber
        case windDown:  return .windDown
        case lightsOut: return .lightsOut
        default:        return nil
        }
    }
}

/// Names for the `ManagedSettingsStore`s, one per phase.
///
/// ManagedSettings persists its stores by name; multiple stores can coexist and their
/// restrictions union together when the system decides whether to shield an app. This
/// lets us "layer" phases: amber restricts nothing (or only the softest set), windDown
/// adds more, lightsOut adds the rest.
public enum PhaseStoreName {
    public static let amber = "phase.amber"
    public static let windDown = "phase.windDown"
    public static let lightsOut = "phase.lightsOut"

    public static func name(for phase: Phase) -> String? {
        switch phase {
        case .amber:     return amber
        case .windDown:  return windDown
        case .lightsOut: return lightsOut
        case .idle:      return nil
        }
    }
}

/// Helpers for building `DeviceActivitySchedule`s from a `LightsOutConfig`.
public enum PhaseScheduleBuilder {

    /// Build the three schedules for a given config. Each schedule spans from its
    /// phase's start to morning-reset, so `intervalDidEnd` fires once at dawn and the
    /// monitor can clear that phase's store.
    ///
    /// Returns `nil` if any of the config times fail to parse.
    public static func buildSchedules(
        from config: LightsOutConfig
    ) -> [(name: DeviceActivityName, schedule: DeviceActivitySchedule)]? {
        guard
            let amberStart = LightsOutCore.parseTime(config.amberTime),
            let windDownStart = LightsOutCore.parseTime(config.winddownTime),
            let lightsOutStart = LightsOutCore.parseTime(config.lightsOutTime),
            let morningReset = LightsOutCore.parseTime(config.morningResetTime)
        else {
            return nil
        }

        let end = DateComponents(hour: morningReset.hour, minute: morningReset.minute)

        return [
            (
                PhaseScheduleName.amber,
                DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: amberStart.hour, minute: amberStart.minute),
                    intervalEnd: end,
                    repeats: true,
                    warningTime: nil
                )
            ),
            (
                PhaseScheduleName.windDown,
                DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: windDownStart.hour, minute: windDownStart.minute),
                    intervalEnd: end,
                    repeats: true,
                    warningTime: nil
                )
            ),
            (
                PhaseScheduleName.lightsOut,
                DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: lightsOutStart.hour, minute: lightsOutStart.minute),
                    intervalEnd: end,
                    repeats: true,
                    warningTime: nil
                )
            ),
        ]
    }
}
