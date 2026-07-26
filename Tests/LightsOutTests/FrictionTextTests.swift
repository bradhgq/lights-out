import XCTest
@testable import LightsOutCore

final class FrictionTextTests: XCTestCase {

    // MARK: - Phrase lists

    func testWindDownPhrases_notEmpty() {
        XCTAssertFalse(FrictionText.windDownPhrases.isEmpty)
    }

    func testEmergencyPhrases_notEmpty() {
        XCTAssertFalse(FrictionText.emergencyPhrases.isEmpty)
    }

    func testPhrasesAreLongEnoughToCauseFriction() {
        // Typing a 5-character phrase doesn't introduce friction. Require at least
        // 40 characters so we're confident the user actually has to think.
        for phrase in FrictionText.windDownPhrases {
            XCTAssertGreaterThanOrEqual(
                phrase.count, 40,
                "wind-down phrase is too short: '\(phrase)'"
            )
        }
        for phrase in FrictionText.emergencyPhrases {
            XCTAssertGreaterThanOrEqual(
                phrase.count, 40,
                "emergency phrase is too short: '\(phrase)'"
            )
        }
    }

    func testPhrasesHaveNoTrailingWhitespace() {
        for phrase in FrictionText.windDownPhrases + FrictionText.emergencyPhrases {
            XCTAssertEqual(
                phrase, phrase.trimmingCharacters(in: .whitespaces),
                "phrase has padding: '\(phrase)'"
            )
        }
    }

    // MARK: - Random pickers

    func testRandomWindDownPhrase_isFromList() {
        for _ in 0..<50 {
            XCTAssertTrue(
                FrictionText.windDownPhrases.contains(FrictionText.randomWindDownPhrase())
            )
        }
    }

    func testRandomEmergencyPhrase_isFromList() {
        for _ in 0..<50 {
            XCTAssertTrue(
                FrictionText.emergencyPhrases.contains(FrictionText.randomEmergencyPhrase())
            )
        }
    }

    // MARK: - Challenge generator

    func testGenerateRandomChallenge_defaultLength() {
        XCTAssertEqual(FrictionText.generateRandomChallenge().count, 20)
    }

    func testGenerateRandomChallenge_customLength() {
        XCTAssertEqual(FrictionText.generateRandomChallenge(length: 5).count, 5)
        XCTAssertEqual(FrictionText.generateRandomChallenge(length: 100).count, 100)
    }

    func testGenerateRandomChallenge_zeroLength() {
        XCTAssertEqual(FrictionText.generateRandomChallenge(length: 0), "")
    }

    func testGenerateRandomChallenge_onlyAllowedChars() {
        let allowed = Set(FrictionText.challengeCharacters)
        for _ in 0..<50 {
            for char in FrictionText.generateRandomChallenge(length: 50) {
                XCTAssertTrue(
                    allowed.contains(char),
                    "generated forbidden character '\(char)'"
                )
            }
        }
    }

    func testGenerateRandomChallenge_excludesAmbiguousChars() {
        // 0/O/o, 1/l/I are excluded to avoid ambiguity.
        let allowed = Set(FrictionText.challengeCharacters)
        for c in "0Ol1I" {
            XCTAssertFalse(allowed.contains(c), "ambiguous '\(c)' should be excluded")
        }
    }

    func testGenerateRandomChallenge_hasVariation() {
        // Two independent 50-char challenges should almost never be identical.
        let a = FrictionText.generateRandomChallenge(length: 50)
        let b = FrictionText.generateRandomChallenge(length: 50)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Match helper

    func testMatches_exact() {
        XCTAssertTrue(FrictionText.matches(typed: "hello world", challenge: "hello world"))
    }

    func testMatches_withWhitespace() {
        XCTAssertTrue(FrictionText.matches(typed: "  hello world  ", challenge: "hello world"))
    }

    func testMatches_mismatchTrailingChar() {
        XCTAssertFalse(FrictionText.matches(typed: "hello world.", challenge: "hello world"))
    }

    func testMatches_caseSensitive() {
        XCTAssertFalse(FrictionText.matches(typed: "Hello World", challenge: "hello world"))
    }

    func testMatches_empty() {
        XCTAssertTrue(FrictionText.matches(typed: "", challenge: ""))
        XCTAssertFalse(FrictionText.matches(typed: "", challenge: "x"))
    }
}
