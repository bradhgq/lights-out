import Foundation
import LightsOutCore

// Simple test harness that works without XCTest/Xcode
var passed = 0
var failed = 0

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: String = #file, line: Int = #line) {
    if a == b {
        passed += 1
    } else {
        failed += 1
        let label = msg.isEmpty ? "" : " — \(msg)"
        print("FAIL [\(file.split(separator: "/").last ?? ""):\(line)]: expected \(b), got \(a)\(label)")
    }
}

func assertNil<T>(_ value: T?, _ msg: String = "", file: String = #file, line: Int = #line) {
    if value == nil {
        passed += 1
    } else {
        failed += 1
        print("FAIL [\(file.split(separator: "/").last ?? ""):\(line)]: expected nil, got \(value!)\(msg.isEmpty ? "" : " — \(msg)")")
    }
}

// MARK: - Helpers

func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int, second: Int = 0) -> Date {
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

let standardConfig = TimelineConfig(
    morningResetTime: "06:00", amberTime: "22:30",
    winddownTime: "23:00", lightsOutTime: "23:30"
)

let midnightConfig = TimelineConfig(
    morningResetTime: "06:00", amberTime: "23:00",
    winddownTime: "00:00", lightsOutTime: "00:30"
)

let lateNightConfig = TimelineConfig(
    morningResetTime: "07:00", amberTime: "23:00",
    winddownTime: "01:00", lightsOutTime: "02:00"
)

// MARK: - Standard Config (no midnight crossing)

print("--- Standard Config ---")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 8, 0)), .idle, "8 AM = idle")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 15, 0)), .idle, "3 PM = idle")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 22, 29)), .idle, "10:29 PM = idle")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 22, 30)), .amber, "10:30 PM = amber")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 22, 45)), .amber, "10:45 PM = amber")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 22, 59)), .amber, "10:59 PM = amber")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 0)), .windDown, "11:00 PM = windDown")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 15)), .windDown, "11:15 PM = windDown")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 29)), .windDown, "11:29 PM = windDown")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 30)), .lightsOut, "11:30 PM = lightsOut")
assertEqual(computePhase(config: standardConfig, at: date(3, 26, 23, 59)), .lightsOut, "11:59 PM = lightsOut")
assertEqual(computePhase(config: standardConfig, at: date(3, 27, 2, 0)), .lightsOut, "2 AM next day = lightsOut")
assertEqual(computePhase(config: standardConfig, at: date(3, 27, 5, 59, second: 59)), .lightsOut, "5:59:59 AM = lightsOut")
assertEqual(computePhase(config: standardConfig, at: date(3, 27, 6, 0)), .idle, "6 AM = idle (morning reset)")

// MARK: - Midnight-Crossing Config (the reported bug)

print("\n--- Midnight-Crossing Config ---")
assertEqual(computePhase(config: midnightConfig, at: date(3, 25, 22, 0)), .idle, "10 PM = idle")
assertEqual(computePhase(config: midnightConfig, at: date(3, 25, 23, 0)), .amber, "11 PM = amber")
assertEqual(computePhase(config: midnightConfig, at: date(3, 25, 23, 30)), .amber, "11:30 PM = amber")
assertEqual(computePhase(config: midnightConfig, at: date(3, 25, 23, 59)), .amber, "11:59 PM = amber")
assertEqual(computePhase(config: midnightConfig, at: date(3, 26, 0, 0)), .windDown, "12:00 AM = windDown")
assertEqual(computePhase(config: midnightConfig, at: date(3, 26, 0, 16)), .windDown, "12:16 AM = windDown (BUG SCENARIO)")
assertEqual(computePhase(config: midnightConfig, at: date(3, 26, 0, 29)), .windDown, "12:29 AM = windDown")
assertEqual(computePhase(config: midnightConfig, at: date(3, 26, 0, 30)), .lightsOut, "12:30 AM = lightsOut")
assertEqual(computePhase(config: midnightConfig, at: date(3, 26, 3, 0)), .lightsOut, "3 AM = lightsOut")
assertEqual(computePhase(config: midnightConfig, at: date(3, 26, 5, 59)), .lightsOut, "5:59 AM = lightsOut")
assertEqual(computePhase(config: midnightConfig, at: date(3, 26, 6, 0)), .idle, "6 AM = idle (morning reset)")
assertEqual(computePhase(config: midnightConfig, at: date(3, 26, 14, 0)), .idle, "2 PM = idle")

// MARK: - Late Night Config (amber before midnight, winddown/lightsOut well after)

print("\n--- Late Night Config ---")
assertEqual(computePhase(config: lateNightConfig, at: date(3, 25, 22, 0)), .idle, "10 PM = idle")
assertEqual(computePhase(config: lateNightConfig, at: date(3, 25, 23, 0)), .amber, "11 PM = amber")
assertEqual(computePhase(config: lateNightConfig, at: date(3, 25, 23, 30)), .amber, "11:30 PM = amber")
assertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 0, 30)), .amber, "12:30 AM = amber")
assertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 1, 0)), .windDown, "1 AM = windDown")
assertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 1, 30)), .windDown, "1:30 AM = windDown")
assertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 2, 0)), .lightsOut, "2 AM = lightsOut")
assertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 5, 0)), .lightsOut, "5 AM = lightsOut")
assertEqual(computePhase(config: lateNightConfig, at: date(3, 26, 7, 0)), .idle, "7 AM = idle (morning reset)")

// MARK: - Phase Skipping (equal times)

print("\n--- Phase Skipping ---")

let skipAmber = TimelineConfig(
    morningResetTime: "06:00", amberTime: "23:00",
    winddownTime: "23:00", lightsOutTime: "23:30"
)
assertEqual(computePhase(config: skipAmber, at: date(3, 26, 22, 0)), .idle, "skip amber: before = idle")
assertEqual(computePhase(config: skipAmber, at: date(3, 26, 23, 0)), .windDown, "skip amber: at time = windDown")
assertEqual(computePhase(config: skipAmber, at: date(3, 26, 23, 30)), .lightsOut, "skip amber: lightsOut")

let skipWinddown = TimelineConfig(
    morningResetTime: "06:00", amberTime: "22:00",
    winddownTime: "23:00", lightsOutTime: "23:00"
)
assertEqual(computePhase(config: skipWinddown, at: date(3, 26, 22, 0)), .amber, "skip winddown: amber")
assertEqual(computePhase(config: skipWinddown, at: date(3, 26, 22, 59)), .amber, "skip winddown: still amber")
assertEqual(computePhase(config: skipWinddown, at: date(3, 26, 23, 0)), .lightsOut, "skip winddown: straight to lightsOut")

let skipBoth = TimelineConfig(
    morningResetTime: "06:00", amberTime: "23:00",
    winddownTime: "23:00", lightsOutTime: "23:00"
)
assertEqual(computePhase(config: skipBoth, at: date(3, 26, 22, 0)), .idle, "skip both: idle")
assertEqual(computePhase(config: skipBoth, at: date(3, 26, 23, 0)), .lightsOut, "skip both: straight to lightsOut")

// MARK: - Timeline Resolution

print("\n--- Timeline Resolution ---")

let t1 = resolveTimeline(config: standardConfig, for: date(3, 26, 15, 0))!
assertEqual(t1.morning, date(3, 26, 6, 0), "standard afternoon: morning")
assertEqual(t1.amber, date(3, 26, 22, 30), "standard afternoon: amber")
assertEqual(t1.winddown, date(3, 26, 23, 0), "standard afternoon: winddown")
assertEqual(t1.lightsOut, date(3, 26, 23, 30), "standard afternoon: lightsOut")
assertEqual(t1.nextMorning, date(3, 27, 6, 0), "standard afternoon: nextMorning")

let t2 = resolveTimeline(config: midnightConfig, for: date(3, 26, 0, 16))!
assertEqual(t2.morning, date(3, 25, 6, 0), "midnight 12:16 AM: morning = yesterday")
assertEqual(t2.amber, date(3, 25, 23, 0), "midnight 12:16 AM: amber")
assertEqual(t2.winddown, date(3, 26, 0, 0), "midnight 12:16 AM: winddown")
assertEqual(t2.lightsOut, date(3, 26, 0, 30), "midnight 12:16 AM: lightsOut")
assertEqual(t2.nextMorning, date(3, 26, 6, 0), "midnight 12:16 AM: nextMorning")

let t3 = resolveTimeline(config: midnightConfig, for: date(3, 25, 22, 0))!
assertEqual(t3.morning, date(3, 25, 6, 0), "midnight evening: morning")
assertEqual(t3.amber, date(3, 25, 23, 0), "midnight evening: amber")
assertEqual(t3.winddown, date(3, 26, 0, 0), "midnight evening: winddown")
assertEqual(t3.lightsOut, date(3, 26, 0, 30), "midnight evening: lightsOut")

// MARK: - Consistency Across Days

print("\n--- Multi-Day Consistency ---")
for day in 24...28 {
    assertEqual(computePhase(config: midnightConfig, at: date(3, day, 14, 0)), .idle, "day \(day) at 2 PM = idle")
    assertEqual(computePhase(config: midnightConfig, at: date(3, day, 23, 30)), .amber, "day \(day) at 11:30 PM = amber")
}

// MARK: - parseTime

print("\n--- parseTime ---")
let p1 = parseTime("22:30")
assertEqual(p1?.hour ?? -1, 22, "parse 22:30 hour")
assertEqual(p1?.minute ?? -1, 30, "parse 22:30 minute")
let p2 = parseTime("00:00")
assertEqual(p2?.hour ?? -1, 0, "parse 00:00 hour")
assertEqual(p2?.minute ?? -1, 0, "parse 00:00 minute")
assertNil(parseTime("25:00"), "reject 25:00")
assertNil(parseTime("12:60"), "reject 12:60")
assertNil(parseTime("abc"), "reject abc")
assertNil(parseTime(""), "reject empty")
assertNil(parseTime("12"), "reject single number")

// MARK: - Summary

print("\n===========================")
if failed == 0 {
    print("ALL \(passed) TESTS PASSED")
} else {
    print("\(failed) FAILED, \(passed) passed")
}
print("===========================")

if failed > 0 {
    exit(1)
}
