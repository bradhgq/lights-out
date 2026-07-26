import XCTest
@testable import LightsOutCore

final class LightsOutConfigTests: XCTestCase {

    // MARK: - Validation: happy path

    func testDefaults_areValid() {
        XCTAssertEqual(LightsOutConfig.defaults.validate(), [])
    }

    func testStandardOrder_isValid() {
        let c = LightsOutConfig(
            amberTime: "22:00", winddownTime: "22:30",
            lightsOutTime: "23:00", morningResetTime: "06:00"
        )
        XCTAssertEqual(c.validate(), [])
    }

    func testMidnightCrossing_isValid() {
        let c = LightsOutConfig(
            amberTime: "23:00", winddownTime: "00:00",
            lightsOutTime: "00:30", morningResetTime: "06:00"
        )
        XCTAssertEqual(c.validate(), [])
    }

    func testPhasesCanBeEqual_amberAndWinddown() {
        // Setting amber == winddown is allowed (effectively skips amber).
        let c = LightsOutConfig(
            amberTime: "23:00", winddownTime: "23:00",
            lightsOutTime: "23:30", morningResetTime: "06:00"
        )
        XCTAssertEqual(c.validate(), [])
    }

    // MARK: - Validation: error paths

    func testInvalidTime_morning() {
        let c = LightsOutConfig(
            amberTime: "22:00", winddownTime: "22:30",
            lightsOutTime: "23:00", morningResetTime: "nope"
        )
        let errors = c.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("morning_reset_time"))
    }

    func testInvalidTime_amber() {
        let c = LightsOutConfig(
            amberTime: "99:99", winddownTime: "22:30",
            lightsOutTime: "23:00", morningResetTime: "06:00"
        )
        XCTAssertTrue(c.validate().contains { $0.contains("amber_time") })
    }

    func testAmberEqualToMorningReset_isInvalid() {
        let c = LightsOutConfig(
            amberTime: "06:00", winddownTime: "22:30",
            lightsOutTime: "23:00", morningResetTime: "06:00"
        )
        XCTAssertTrue(c.validate().contains { $0.contains("must be different") })
    }

    func testWinddownBeforeAmber_isInvalid() {
        // Wind-down at 22:00, amber at 22:30 → wind-down is before amber in the cycle.
        let c = LightsOutConfig(
            amberTime: "22:30", winddownTime: "22:00",
            lightsOutTime: "23:00", morningResetTime: "06:00"
        )
        XCTAssertTrue(c.validate().contains { $0.contains("winddown_time") })
    }

    func testLightsOutBeforeWinddown_isInvalid() {
        let c = LightsOutConfig(
            amberTime: "22:00", winddownTime: "23:00",
            lightsOutTime: "22:45", morningResetTime: "06:00"
        )
        XCTAssertTrue(c.validate().contains { $0.contains("lights_out_time") })
    }

    // MARK: - Codable round-trip

    func testCodable_roundTrip_defaults() throws {
        let encoded = try JSONEncoder().encode(LightsOutConfig.defaults)
        let decoded = try JSONDecoder().decode(LightsOutConfig.self, from: encoded)
        XCTAssertEqual(decoded, LightsOutConfig.defaults)
    }

    func testCodable_usesSnakeCaseKeys() throws {
        let encoded = try JSONEncoder().encode(LightsOutConfig.defaults)
        let json = String(data: encoded, encoding: .utf8) ?? ""
        // Sanity-check that the on-disk schema is snake_case, not camelCase.
        XCTAssertTrue(json.contains("\"amber_time\""))
        XCTAssertTrue(json.contains("\"morning_reset_time\""))
        XCTAssertTrue(json.contains("\"friction_delays_seconds\""))
        XCTAssertFalse(json.contains("\"amberTime\""))
    }

    func testCodable_grayscaleFields() throws {
        var config = LightsOutConfig.defaults
        config.grayscaleOnShortcutName = "Custom On"
        config.grayscaleOffShortcutName = "Custom Off"
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LightsOutConfig.self, from: encoded)
        XCTAssertEqual(decoded.grayscaleOnShortcutName, "Custom On")
        XCTAssertEqual(decoded.grayscaleOffShortcutName, "Custom Off")
    }

    // MARK: - Timeline config bridge

    func testTimelineConfig_mapsAllFourTimes() {
        let config = LightsOutConfig(
            amberTime: "22:00", winddownTime: "22:30",
            lightsOutTime: "23:00", morningResetTime: "06:00"
        )
        let tc = config.timelineConfig
        XCTAssertEqual(tc.amberTime, "22:00")
        XCTAssertEqual(tc.winddownTime, "22:30")
        XCTAssertEqual(tc.lightsOutTime, "23:00")
        XCTAssertEqual(tc.morningResetTime, "06:00")
    }

    // MARK: - Equatable

    func testEquatable_identical() {
        XCTAssertEqual(LightsOutConfig.defaults, LightsOutConfig.defaults)
    }

    func testEquatable_different() {
        var a = LightsOutConfig.defaults
        var b = LightsOutConfig.defaults
        b.amberTime = "21:00"
        XCTAssertNotEqual(a, b)
        _ = a   // silence unused-mutable warning
    }
}
