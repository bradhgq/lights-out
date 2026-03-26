import XCTest
@testable import LightsOutCore

final class TimelineTests: XCTestCase {

    // MARK: - Helpers

    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int, second: Int = 0) -> Date {
        var c = DateComponents()
        c.year = 2026
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.second = second
        return Calendar.current.date(from: c)!
    }

    // MARK: - Configs

    private let standardConfig = TimelineConfig(
        morningResetTime: "06:00", amberTime: "22:30",
        winddownTime: "23:00", lightsOutTime: "23:30"
    )

    private let midnightConfig = TimelineConfig(
        morningResetTime: "06:00", amberTime: "23:00",
        winddownTime: "00:00", lightsOutTime: "00:30"
    )

    private let lateNightConfig = TimelineConfig(
        morningResetTime: "07:00", amberTime: "23:00",
        winddownTime: "01:00", lightsOutTime: "02:00"
    )

    // MARK: - Standard Config (no midnight crossing)

    func testStandard_morning_isIdle() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 8, 0)), .idle)
    }

    func testStandard_afternoon_isIdle() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 15, 0)), .idle)
    }

    func testStandard_oneMinuteBeforeAmber_isIdle() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 22, 29)), .idle)
    }

    func testStandard_atAmber_isAmber() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 22, 30)), .amber)
    }

    func testStandard_duringAmber_isAmber() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 22, 45)), .amber)
    }

    func testStandard_lastMinuteOfAmber_isAmber() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 22, 59)), .amber)
    }

    func testStandard_atWinddown_isWindDown() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 0)), .windDown)
    }

    func testStandard_duringWinddown_isWindDown() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 15)), .windDown)
    }

    func testStandard_lastMinuteOfWinddown_isWindDown() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 29)), .windDown)
    }

    func testStandard_atLightsOut_isLightsOut() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 30)), .lightsOut)
    }

    func testStandard_endOfDay_isLightsOut() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 59)), .lightsOut)
    }

    func testStandard_afterMidnight_isLightsOut() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 27, 2, 0)), .lightsOut)
    }

    func testStandard_justBeforeMorningReset_isLightsOut() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 27, 5, 59, second: 59)), .lightsOut)
    }

    func testStandard_atMorningReset_isIdle() {
        XCTAssertEqual(computePhase(config: standardConfig, at: date(3, 27, 6, 0)), .idle)
    }

    // MARK: - Midnight-Crossing Config (the reported bug)

    func testMidnight_beforeAmber_isIdle() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 25, 22, 0)), .idle)
    }

    func testMidnight_atAmber_isAmber() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 25, 23, 0)), .amber)
    }

    func testMidnight_duringAmber_isAmber() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 25, 23, 30)), .amber)
    }

    func testMidnight_lastMinuteOfAmber_isAmber() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 25, 23, 59)), .amber)
    }

    func testMidnight_atWinddown_isWindDown() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 26, 0, 0)), .windDown)
    }

    func testMidnight_bugScenario_1216AM_isWindDown() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 26, 0, 16)), .windDown)
    }

    func testMidnight_lastMinuteOfWinddown_isWindDown() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 26, 0, 29)), .windDown)
    }

    func testMidnight_atLightsOut_isLightsOut() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 26, 0, 30)), .lightsOut)
    }

    func testMidnight_deepNight_isLightsOut() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 26, 3, 0)), .lightsOut)
    }

    func testMidnight_justBeforeReset_isLightsOut() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 26, 5, 59)), .lightsOut)
    }

    func testMidnight_atMorningReset_isIdle() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 26, 6, 0)), .idle)
    }

    func testMidnight_nextDayAfternoon_isIdle() {
        XCTAssertEqual(computePhase(config: midnightConfig, at: date(3, 26, 14, 0)), .idle)
    }

    // MARK: - Late Night Config

    func testLateNight_beforeAmber_isIdle() {
        XCTAssertEqual(computePhase(config: lateNightConfig, at: date(3, 25, 22, 0)), .idle)
    }

    func testLateNight_atAmber_isAmber() {
        XCTAssertEqual(computePhase(config: lateNightConfig, at: date(3, 25, 23, 0)), .amber)
    }

    func testLateNight_duringAmber_isAmber() {
        XCTAssertEqual(computePhase(config: lateNightConfig, at: date(3, 25, 23, 30)), .amber)
    }

    func testLateNight_afterMidnight_stillAmber() {
        XCTAssertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 0, 30)), .amber)
    }

    func testLateNight_atWinddown_isWindDown() {
        XCTAssertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 1, 0)), .windDown)
    }

    func testLateNight_duringWinddown_isWindDown() {
        XCTAssertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 1, 30)), .windDown)
    }

    func testLateNight_atLightsOut_isLightsOut() {
        XCTAssertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 2, 0)), .lightsOut)
    }

    func testLateNight_deepNight_isLightsOut() {
        XCTAssertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 5, 0)), .lightsOut)
    }

    func testLateNight_atMorningReset_isIdle() {
        XCTAssertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 7, 0)), .idle)
    }

    // MARK: - Phase Skipping (equal times)

    func testSkipAmber_goesDirectlyToWindDown() {
        let config = TimelineConfig(
            morningResetTime: "06:00", amberTime: "23:00",
            winddownTime: "23:00", lightsOutTime: "23:30"
        )
        XCTAssertEqual(computePhase(config: config, at: date(3, 26, 22, 0)), .idle)
        XCTAssertEqual(computePhase(config: config, at: date(3, 26, 23, 0)), .windDown)
        XCTAssertEqual(computePhase(config: config, at: date(3, 26, 23, 30)), .lightsOut)
    }

    func testSkipWinddown_goesDirectlyToLightsOut() {
        let config = TimelineConfig(
            morningResetTime: "06:00", amberTime: "22:00",
            winddownTime: "23:00", lightsOutTime: "23:00"
        )
        XCTAssertEqual(computePhase(config: config, at: date(3, 26, 22, 0)), .amber)
        XCTAssertEqual(computePhase(config: config, at: date(3, 26, 22, 59)), .amber)
        XCTAssertEqual(computePhase(config: config, at: date(3, 26, 23, 0)), .lightsOut)
    }

    func testSkipAmberAndWinddown_goesDirectlyToLightsOut() {
        let config = TimelineConfig(
            morningResetTime: "06:00", amberTime: "23:00",
            winddownTime: "23:00", lightsOutTime: "23:00"
        )
        XCTAssertEqual(computePhase(config: config, at: date(3, 26, 22, 0)), .idle)
        XCTAssertEqual(computePhase(config: config, at: date(3, 26, 23, 0)), .lightsOut)
    }

    // MARK: - Timeline Resolution

    func testTimeline_standardAfternoon() {
        let t = resolveTimeline(config: standardConfig, for: date(3, 26, 15, 0))!
        XCTAssertEqual(t.morning, date(3, 26, 6, 0))
        XCTAssertEqual(t.amber, date(3, 26, 22, 30))
        XCTAssertEqual(t.winddown, date(3, 26, 23, 0))
        XCTAssertEqual(t.lightsOut, date(3, 26, 23, 30))
        XCTAssertEqual(t.nextMorning, date(3, 27, 6, 0))
    }

    func testTimeline_midnightCrossing_atBugTime() {
        let t = resolveTimeline(config: midnightConfig, for: date(3, 26, 0, 16))!
        XCTAssertEqual(t.morning, date(3, 25, 6, 0))
        XCTAssertEqual(t.amber, date(3, 25, 23, 0))
        XCTAssertEqual(t.winddown, date(3, 26, 0, 0))
        XCTAssertEqual(t.lightsOut, date(3, 26, 0, 30))
        XCTAssertEqual(t.nextMorning, date(3, 26, 6, 0))
    }

    func testTimeline_midnightCrossing_evening() {
        let t = resolveTimeline(config: midnightConfig, for: date(3, 25, 22, 0))!
        XCTAssertEqual(t.morning, date(3, 25, 6, 0))
        XCTAssertEqual(t.amber, date(3, 25, 23, 0))
        XCTAssertEqual(t.winddown, date(3, 26, 0, 0))
        XCTAssertEqual(t.lightsOut, date(3, 26, 0, 30))
    }

    // MARK: - Multi-Day Consistency

    func testConsistentAcrossMultipleDays() {
        for day in 24...28 {
            XCTAssertEqual(
                computePhase(config: midnightConfig, at: date(3, day, 14, 0)), .idle,
                "Day \(day) at 2 PM"
            )
            XCTAssertEqual(
                computePhase(config: midnightConfig, at: date(3, day, 23, 30)), .amber,
                "Day \(day) at 11:30 PM"
            )
        }
    }

    // MARK: - parseTime

    func testParseTime_valid() {
        let r = parseTime("22:30")
        XCTAssertEqual(r?.hour, 22)
        XCTAssertEqual(r?.minute, 30)
    }

    func testParseTime_midnight() {
        let r = parseTime("00:00")
        XCTAssertEqual(r?.hour, 0)
        XCTAssertEqual(r?.minute, 0)
    }

    func testParseTime_invalidHour() {
        XCTAssertNil(parseTime("25:00"))
    }

    func testParseTime_invalidMinute() {
        XCTAssertNil(parseTime("12:60"))
    }

    func testParseTime_garbage() {
        XCTAssertNil(parseTime("abc"))
    }

    func testParseTime_empty() {
        XCTAssertNil(parseTime(""))
    }

    func testParseTime_noColon() {
        XCTAssertNil(parseTime("12"))
    }
}
