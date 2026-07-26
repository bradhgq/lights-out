import Foundation
import LightsOutCore

enum Constants {
    static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".lightsout")
    static let configFile = configDirectory.appendingPathComponent("config.json")
    static let overridesFile = configDirectory.appendingPathComponent("overrides.json")

    static let hostsFilePath = "/etc/hosts"
    static let hostsBeginMarker = "# BEGIN LIGHTSOUT"
    static let hostsEndMarker = "# END LIGHTSOUT"

    static let overrideDurationChoices = [5, 15] // minutes

    #if DEV_MODE
    static var devMode = false
    #endif

    /// Fixed short phrase used during dev mode to make testing the friction flow fast.
    /// Production phrases live in `LightsOutCore.FrictionText`.
    private static let devWindDownPhrase = "I want to stay up"
    private static let devEmergencyPhrase = "This is an emergency"
    private static let devChallenge = "abc123"

    static func randomWindDownPhrase() -> String {
        #if DEV_MODE
        if devMode { return devWindDownPhrase }
        #endif
        return FrictionText.randomWindDownPhrase()
    }

    static func randomEmergencyPhrase() -> String {
        #if DEV_MODE
        if devMode { return devEmergencyPhrase }
        #endif
        return FrictionText.randomEmergencyPhrase()
    }

    /// Generate a random string of mixed-case letters and digits that's hard to type.
    static func generateRandomChallenge(length: Int = 20) -> String {
        #if DEV_MODE
        if devMode { return devChallenge }
        #endif
        return FrictionText.generateRandomChallenge(length: length)
    }
}
