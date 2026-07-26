public enum Phase: String, Codable {
    case idle
    case amber
    case windDown
    case lightsOut
}

extension Phase {
    /// Restrictiveness ordering: idle < amber < windDown < lightsOut.
    public var severity: Int {
        switch self {
        case .idle:      return 0
        case .amber:     return 1
        case .windDown:  return 2
        case .lightsOut: return 3
        }
    }

    /// Whether this phase's restrictions should be in force given `current` is the
    /// active phase.
    ///
    /// Phases *layer* rather than replace: each one's schedule runs from its own start
    /// time until morning reset, so during lights-out the amber and wind-down intervals
    /// are still open and their stores still shielding. Anything reconciling shield
    /// state after an interruption has to restore all of them, not just the newest.
    public func isInForce(whenCurrentIs current: Phase) -> Bool {
        severity > 0 && severity <= current.severity
    }
}
