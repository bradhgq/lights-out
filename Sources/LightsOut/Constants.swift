import Foundation

enum Constants {
    static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".lightsout")
    static let configFile = configDirectory.appendingPathComponent("config.json")
    static let overridesFile = configDirectory.appendingPathComponent("overrides.json")

    static let hostsFilePath = "/etc/hosts"
    static let hostsBeginMarker = "# BEGIN LIGHTSOUT"
    static let hostsEndMarker = "# END LIGHTSOUT"

    static let overrideDurationChoices = [5, 15] // minutes

    static let windDownPhrases = [
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

    static let emergencyPhrases = [
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

    static func randomWindDownPhrase() -> String {
        windDownPhrases.randomElement()!
    }

    static func randomEmergencyPhrase() -> String {
        emergencyPhrases.randomElement()!
    }

    /// Generate a random string of mixed-case letters and digits that's hard to type.
    static func generateRandomChallenge(length: Int = 20) -> String {
        let chars = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
