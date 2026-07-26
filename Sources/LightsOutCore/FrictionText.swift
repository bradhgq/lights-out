import Foundation

/// Shared friction phrases and challenge generators used by both macOS and iOS targets.
///
/// Friction text is the core of the override flow: a wall of typing that forces the user
/// to consciously commit to staying up. The wind-down phrases are long enough that typing
/// them is tedious; the emergency phrases are used when the user has already exhausted
/// their overrides for the night.
public enum FrictionText {

    /// Phrases shown during the wind-down override flow (lighter friction — the user
    /// has overrides remaining). Each is long enough that typing it on a phone or laptop
    /// takes measurable effort and time.
    public static let windDownPhrases: [String] = [
        "I am choosing to stay up and I know I will regret this tomorrow",
        "Sleep is more important than whatever I think I need to do right now",
        "I am trading tomorrow's energy for a few more minutes of screen time",
        "Nothing on the internet is worth being tired at work tomorrow",
        "Future me will be disappointed that I am making this choice",
        "I am actively choosing short term comfort over long term wellbeing",
        "This is not urgent and it can wait until morning when I am rested",
        "Every minute I stay up now is a minute of sleep I will never get back",
        "I have never once woken up and wished I had stayed up later last night",
        "The best version of myself would close the laptop and go to bed now",
    ]

    /// Phrases shown during the lights-out emergency override (maximum friction —
    /// the user has used all their regular overrides). Paired with a random-string
    /// challenge so muscle memory can't help.
    public static let emergencyPhrases: [String] = [
        "This is a true emergency and I really need to use this app right now",
        "I solemnly declare this cannot wait until morning and accept the consequences",
        "I am overriding lights out because there is a genuine urgent situation happening",
        "I understand this is meant to help me sleep and I am choosing to ignore it",
        "Nothing about this situation will improve by me staying up but here I am",
        "I am fully aware that this override exists for emergencies and this better be one",
        "I promise I will go to bed immediately after handling this one specific thing",
        "This is not doomscrolling I actually need to do something important right now",
        "I accept that I am undermining my own sleep goals by typing this sentence",
        "If I am being honest with myself this is probably not actually an emergency",
    ]

    /// Characters used for random-string challenges. Excludes visually ambiguous
    /// characters (0/O, 1/l/I) so transcription errors are about typing, not reading.
    public static let challengeCharacters =
        "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    /// Pick a random wind-down phrase. Caller is responsible for seeding or
    /// holding the result (don't re-call this inside a SwiftUI view body).
    public static func randomWindDownPhrase() -> String {
        windDownPhrases.randomElement()!
    }

    /// Pick a random emergency phrase.
    public static func randomEmergencyPhrase() -> String {
        emergencyPhrases.randomElement()!
    }

    /// Generate a random case-mixed alphanumeric challenge string.
    /// Default length of 20 takes roughly 8–15 seconds to type accurately.
    public static func generateRandomChallenge(length: Int = 20) -> String {
        precondition(length >= 0, "challenge length must be non-negative")
        return String((0..<length).map { _ in challengeCharacters.randomElement()! })
    }

    /// Trim whitespace and compare to target. Used to check if a user's typed
    /// phrase matches the challenge exactly (after ignoring edge whitespace).
    public static func matches(typed: String, challenge: String) -> Bool {
        typed.trimmingCharacters(in: .whitespaces) == challenge
    }
}
