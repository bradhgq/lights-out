import Foundation

enum Phase: String, Codable {
    case idle
    case amber
    case windDown
    case lightsOut
}

protocol PhaseManagerDelegate: AnyObject {
    func phaseDidChange(to phase: Phase)
    func countdownDidUpdate(_ text: String)
    func morningResetTriggered()
}

class PhaseManager {
    weak var delegate: PhaseManagerDelegate?
    private(set) var currentPhase: Phase = .idle

    private(set) var config: LightsOutConfig
    private var timer: Timer?

    // Dev mode
    private(set) var devMode = false
    private var devOverride: Phase?
    private var devCycling = false
    private var devCycleTimer: Timer?
    private var devCycleSecondsRemaining = 0
    private let devCycleDuration = 15 // seconds per phase when auto-cycling

    init(config: LightsOutConfig) {
        self.config = config
    }

    func updateConfig(_ newConfig: LightsOutConfig) {
        self.config = newConfig
        if !devMode {
            let newPhase = computePhase()
            if newPhase != currentPhase {
                let oldPhase = currentPhase
                currentPhase = newPhase
                delegate?.phaseDidChange(to: currentPhase)
                if oldPhase == .lightsOut && newPhase == .idle {
                    delegate?.morningResetTriggered()
                }
            }
            updateCountdown()
        }
    }

    func start() {
        // Determine initial phase based on current time
        let newPhase = computePhase()
        if newPhase != currentPhase {
            currentPhase = newPhase
            delegate?.phaseDidChange(to: currentPhase)
        }
        updateCountdown()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        stopDevCycle()
    }

    // MARK: - Dev Mode

    func setDevMode(_ enabled: Bool) {
        devMode = enabled
        if !enabled {
            devOverride = nil
            stopDevCycle()
            // Re-evaluate real phase
            let newPhase = computePhase()
            if newPhase != currentPhase {
                currentPhase = newPhase
                delegate?.phaseDidChange(to: currentPhase)
            }
        }
        updateCountdown()
    }

    func forcePhase(_ phase: Phase) {
        guard devMode else { return }
        stopDevCycle()
        devOverride = phase
        let oldPhase = currentPhase
        currentPhase = phase
        delegate?.phaseDidChange(to: phase)
        if oldPhase == .lightsOut && phase == .idle {
            delegate?.morningResetTriggered()
        }
        updateCountdown()
    }

    func toggleDevCycle() {
        guard devMode else { return }
        if devCycling {
            stopDevCycle()
        } else {
            startDevCycle()
        }
        updateCountdown()
    }

    var isDevCycling: Bool { devCycling }

    private func startDevCycle() {
        devCycling = true
        devCycleSecondsRemaining = devCycleDuration
        devOverride = .idle
        let oldPhase = currentPhase
        currentPhase = .idle
        delegate?.phaseDidChange(to: .idle)
        if oldPhase == .lightsOut {
            delegate?.morningResetTriggered()
        }

        devCycleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.devCycleTick()
        }
        if let t = devCycleTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func stopDevCycle() {
        devCycling = false
        devCycleTimer?.invalidate()
        devCycleTimer = nil
    }

    private func devCycleTick() {
        devCycleSecondsRemaining -= 1
        if devCycleSecondsRemaining <= 0 {
            advanceDevPhase()
            devCycleSecondsRemaining = devCycleDuration
        }
        updateCountdown()
    }

    private static let phaseOrder: [Phase] = [.idle, .amber, .windDown, .lightsOut]

    private func advanceDevPhase() {
        guard let current = devOverride,
              let idx = Self.phaseOrder.firstIndex(of: current) else { return }
        let nextIdx = (idx + 1) % Self.phaseOrder.count
        let nextPhase = Self.phaseOrder[nextIdx]
        devOverride = nextPhase
        let oldPhase = currentPhase
        currentPhase = nextPhase
        delegate?.phaseDidChange(to: nextPhase)
        if oldPhase == .lightsOut && nextPhase == .idle {
            delegate?.morningResetTriggered()
        }
    }

    private func tick() {
        if devMode {
            // In dev mode, don't auto-compute phase from clock
            updateCountdown()
            return
        }
        let newPhase = computePhase()
        if newPhase != currentPhase {
            let oldPhase = currentPhase
            currentPhase = newPhase
            delegate?.phaseDidChange(to: currentPhase)
            if oldPhase == .lightsOut && newPhase == .idle {
                delegate?.morningResetTriggered()
            }
        }
        updateCountdown()
    }

    /// Resolved timeline dates for the current cycle, anchored to the most recent morning reset.
    private struct Timeline {
        let morning: Date
        let amber: Date
        let winddown: Date
        let lightsOut: Date
        let nextMorning: Date
    }

    private func resolveTimeline(for now: Date) -> Timeline? {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)

        guard let morningBase = makeDate(todayComponents, time: config.morningResetTime),
              let amberBase = makeDate(todayComponents, time: config.amberTime),
              let winddownBase = makeDate(todayComponents, time: config.winddownTime),
              let lightsOutBase = makeDate(todayComponents, time: config.lightsOutTime)
        else {
            return nil
        }

        // Anchor to the most recent morning reset
        let morning: Date
        if now >= morningBase {
            morning = morningBase
        } else {
            morning = calendar.date(byAdding: .day, value: -1, to: morningBase)!
        }

        // Each subsequent time: if it's not after the previous one, push it forward a day
        let amber = amberBase >= morning ? amberBase : calendar.date(byAdding: .day, value: 1, to: amberBase)!
        let winddown = winddownBase >= amber ? winddownBase : calendar.date(byAdding: .day, value: 1, to: winddownBase)!
        let lightsOut = lightsOutBase >= winddown ? lightsOutBase : calendar.date(byAdding: .day, value: 1, to: lightsOutBase)!
        let nextMorning = calendar.date(byAdding: .day, value: 1, to: morning)!

        return Timeline(morning: morning, amber: amber, winddown: winddown, lightsOut: lightsOut, nextMorning: nextMorning)
    }

    private func computePhase() -> Phase {
        let now = Date()
        guard let t = resolveTimeline(for: now) else { return .idle }

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

    private func makeDate(_ dayComponents: DateComponents, time: String) -> Date? {
        guard let (hour, minute) = config.parseTime(time) else { return nil }
        var components = dayComponents
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)
    }

    private func updateCountdown() {
        if devMode {
            let phaseName: String
            switch currentPhase {
            case .idle: phaseName = "Idle"
            case .amber: phaseName = "Amber"
            case .windDown: phaseName = "Wind-Down"
            case .lightsOut: phaseName = "Lights Out"
            }
            if devCycling {
                delegate?.countdownDidUpdate("[DEV] \(phaseName) \(devCycleSecondsRemaining)s")
            } else {
                delegate?.countdownDidUpdate("[DEV] \(phaseName)")
            }
            return
        }

        let now = Date()
        guard let t = resolveTimeline(for: now) else {
            delegate?.countdownDidUpdate("Lights Out")
            return
        }

        // Find the next real phase (skip any with 0-duration)
        let text: String
        switch currentPhase {
        case .idle:
            let (label, target) = nextPhaseAfterIdle(t)
            text = formatNextPhase(label: label, targetDate: target, now: now)
        case .amber:
            let (label, target) = nextPhaseAfterAmber(t)
            text = formatNextPhase(label: label, targetDate: target, now: now)
        case .windDown:
            text = formatNextPhase(label: "Lights out", targetDate: t.lightsOut, now: now)
        case .lightsOut:
            text = "Lights Out"
        }

        delegate?.countdownDidUpdate(text)
    }

    /// From idle, find the first non-skipped phase.
    private func nextPhaseAfterIdle(_ t: Timeline) -> (String, Date) {
        if t.amber != t.winddown { return ("Amber", t.amber) }
        if t.winddown != t.lightsOut { return ("Wind-down", t.winddown) }
        return ("Lights out", t.lightsOut)
    }

    /// From amber, find the next non-skipped phase.
    private func nextPhaseAfterAmber(_ t: Timeline) -> (String, Date) {
        if t.winddown != t.lightsOut { return ("Wind-down", t.winddown) }
        return ("Lights out", t.lightsOut)
    }

    private func formatNextPhase(label: String, targetDate: Date, now: Date) -> String {
        let interval = targetDate.timeIntervalSince(now)
        if interval > 3600 {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "\(label) at \(formatter.string(from: targetDate))"
        }
        return "\(label) in \(formatInterval(interval))"
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
