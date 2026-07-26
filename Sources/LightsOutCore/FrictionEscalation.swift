import Foundation

/// Decides how much friction a given override attempt should face.
///
/// `LightsOutConfig.frictionDelaysSeconds` models an escalating series: the first
/// override of the night is cheap, each subsequent one costs more, and once the list is
/// exhausted the user is pushed onto the emergency path (harder phrase + a random
/// challenge string). The array's *length* is therefore the number of ordinary
/// overrides granted per night, and its *values* are the forced wait before each.
///
/// This is pure so both platforms can share it and so it can actually be tested —
/// the surrounding Screen Time machinery cannot be.
public enum FrictionEscalation {

    /// Fallback wait when a config supplies no delays at all.
    public static let defaultDelaySeconds = 60

    /// Forced wait, in seconds, for the next override given how many have already been
    /// granted tonight. Clamps to the final entry rather than running off the end, so a
    /// user who somehow gets past the emergency gate still faces the harshest wait.
    ///
    /// - Parameters:
    ///   - grantedTonight: overrides already granted this night (0 for the first).
    ///   - delays: `LightsOutConfig.frictionDelaysSeconds`.
    public static func delaySeconds(grantedTonight: Int, delays: [Int]) -> Int {
        guard !delays.isEmpty else { return defaultDelaySeconds }
        let index = min(max(grantedTonight, 0), delays.count - 1)
        return delays[index]
    }

    /// Whether this override attempt uses the emergency path.
    ///
    /// True when the user has spent every ordinary override for the night, or when
    /// they're already past lights-out — at that point there is no "ordinary" override
    /// left to give.
    public static func isEmergency(grantedTonight: Int, delays: [Int], phase: Phase) -> Bool {
        if phase == .lightsOut { return true }
        return grantedTonight >= delays.count
    }

    /// Ordinary overrides still available tonight. Zero means the next attempt is an
    /// emergency override. Useful for telling the user where they stand *before* they
    /// commit to typing.
    public static func remainingOrdinaryOverrides(grantedTonight: Int, delays: [Int]) -> Int {
        max(0, delays.count - max(grantedTonight, 0))
    }
}
