import Foundation

public struct Timeline {
    public let morning: Date
    public let amber: Date
    public let winddown: Date
    public let lightsOut: Date
    public let nextMorning: Date
}

public struct TimelineConfig {
    public let morningResetTime: String
    public let amberTime: String
    public let winddownTime: String
    public let lightsOutTime: String

    public init(morningResetTime: String, amberTime: String, winddownTime: String, lightsOutTime: String) {
        self.morningResetTime = morningResetTime
        self.amberTime = amberTime
        self.winddownTime = winddownTime
        self.lightsOutTime = lightsOutTime
    }
}

public func resolveTimeline(config: TimelineConfig, for now: Date) -> Timeline? {
    let calendar = Calendar.current
    let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)

    guard let morningBase = makeDate(calendar, todayComponents, time: config.morningResetTime) else {
        return nil
    }

    // Anchor to the most recent morning reset
    let morning: Date
    if now >= morningBase {
        morning = morningBase
    } else {
        morning = calendar.date(byAdding: .day, value: -1, to: morningBase)!
    }

    // Build all times from the morning anchor's date, not today's
    let anchorComponents = calendar.dateComponents([.year, .month, .day], from: morning)

    guard let amberBase = makeDate(calendar, anchorComponents, time: config.amberTime),
          let winddownBase = makeDate(calendar, anchorComponents, time: config.winddownTime),
          let lightsOutBase = makeDate(calendar, anchorComponents, time: config.lightsOutTime)
    else {
        return nil
    }

    // Each subsequent time: if it's not after the previous one, push it forward a day
    let amber = amberBase >= morning ? amberBase : calendar.date(byAdding: .day, value: 1, to: amberBase)!
    let winddown = winddownBase >= amber ? winddownBase : calendar.date(byAdding: .day, value: 1, to: winddownBase)!
    let lightsOut = lightsOutBase >= winddown ? lightsOutBase : calendar.date(byAdding: .day, value: 1, to: lightsOutBase)!
    let nextMorning = calendar.date(byAdding: .day, value: 1, to: morning)!

    return Timeline(morning: morning, amber: amber, winddown: winddown, lightsOut: lightsOut, nextMorning: nextMorning)
}

public func computePhase(config: TimelineConfig, at now: Date) -> Phase {
    guard let t = resolveTimeline(config: config, for: now) else { return .idle }

    if now >= t.lightsOut && now < t.nextMorning {
        return .lightsOut
    }
    if now >= t.winddown && now < t.lightsOut {
        return .windDown
    }
    if now >= t.amber && now < t.winddown {
        return .amber
    }
    return .idle
}

private func makeDate(_ calendar: Calendar, _ dayComponents: DateComponents, time: String) -> Date? {
    guard let (hour, minute) = parseTime(time) else { return nil }
    var components = dayComponents
    components.hour = hour
    components.minute = minute
    components.second = 0
    return calendar.date(from: components)
}

public func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
    let parts = timeString.split(separator: ":")
    guard parts.count == 2,
          let hour = Int(parts[0]),
          let minute = Int(parts[1]),
          (0...23).contains(hour),
          (0...59).contains(minute) else { return nil }
    return (hour, minute)
}
