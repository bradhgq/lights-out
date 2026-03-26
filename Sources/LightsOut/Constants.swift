import Foundation

enum Constants {
    static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".lightsout")
    static let configFile = configDirectory.appendingPathComponent("config.json")
    static let overridesFile = configDirectory.appendingPathComponent("overrides.json")

    static let hostsFilePath = "/etc/hosts"
    static let hostsBeginMarker = "# BEGIN LIGHTSOUT"
    static let hostsEndMarker = "# END LIGHTSOUT"

    static let overridePhrase = "I am choosing to stay up"
    static let emergencyPhrase = "This is a true emergency and I really need to use this app right now"

    /// Generate a random string of mixed-case letters and digits that's hard to type.
    static func generateRandomChallenge(length: Int = 20) -> String {
        let chars = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
