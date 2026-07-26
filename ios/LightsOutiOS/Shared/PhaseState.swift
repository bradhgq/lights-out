import Foundation
import LightsOutCore

/// Shared read/write access to the "current phase" state persisted in App Group.
///
/// The monitor extension writes this at phase boundaries. The main app polls it on
/// foreground, and the shield configuration extension reads it when rendering a
/// shield to decide which phase's styling to use.
public enum PhaseState {

    /// Current phase as known by the most recent monitor-extension callback.
    /// Falls back to computing from the current time + config when nothing has been
    /// persisted (first launch before any phase has started).
    public static var current: Phase {
        get {
            if let raw = AppGroup.userDefaults.string(forKey: AppGroupKey.currentPhase),
               let phase = Phase(rawValue: raw)
            {
                return phase
            }
            // Fall back to computed phase so the UI is never "unknown".
            return computePhase(config: ConfigStore.load().timelineConfig, at: Date())
        }
        set {
            AppGroup.userDefaults.set(newValue.rawValue, forKey: AppGroupKey.currentPhase)
            AppGroup.userDefaults.set(Date(), forKey: AppGroupKey.currentPhaseSince)
        }
    }

    /// When the current phase began. `nil` if never recorded.
    public static var since: Date? {
        AppGroup.userDefaults.object(forKey: AppGroupKey.currentPhaseSince) as? Date
    }

    /// Compute the phase on-demand for UI countdowns, without touching persisted state.
    public static func computedPhase(at date: Date = Date()) -> Phase {
        computePhase(config: ConfigStore.load().timelineConfig, at: date)
    }

    /// Resolve the full timeline around a given moment, for countdown UIs.
    public static func timeline(at date: Date = Date()) -> Timeline? {
        resolveTimeline(config: ConfigStore.load().timelineConfig, for: date)
    }
}
