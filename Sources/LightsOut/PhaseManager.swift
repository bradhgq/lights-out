import Foundation
import LightsOutCore

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

    init(config: LightsOutConfig) {
        self.config = config
    }

    func updateConfig(_ newConfig: LightsOutConfig) {
        self.config = newConfig
        if !devMode {
            let newPhase = computePhase(config: config, at: Date())
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
        let newPhase = computePhase(config: config, at: Date())
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
    }

    // MARK: - Dev Mode

    func setDevMode(_ enabled: Bool) {
        devMode = enabled
        Constants.devMode = enabled
        if !enabled {
            devOverride = nil
            let newPhase = computePhase(config: config, at: Date())
            if newPhase != currentPhase {
                currentPhase = newPhase
                delegate?.phaseDidChange(to: currentPhase)
            }
        }
        updateCountdown()
    }

    func forcePhase(_ phase: Phase) {
        guard devMode else { return }

        devOverride = phase
        let oldPhase = currentPhase
        currentPhase = phase
        delegate?.phaseDidChange(to: phase)
        if oldPhase == .lightsOut && phase == .idle {
            delegate?.morningResetTriggered()
        }
        updateCountdown()
    }

    private func tick() {
        if devMode {
            updateCountdown()
            return
        }
        let newPhase = computePhase(config: config, at: Date())
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

    private var timelineConfig: TimelineConfig {
        TimelineConfig(
            morningResetTime: config.morningResetTime,
            amberTime: config.amberTime,
            winddownTime: config.winddownTime,
            lightsOutTime: config.lightsOutTime
        )
    }

    private func computePhase(config: LightsOutConfig, at now: Date) -> Phase {
        LightsOutCore.computePhase(config: timelineConfig, at: now)
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
            delegate?.countdownDidUpdate("[DEV] \(phaseName)")
            return
        }

        let now = Date()
        guard let t = resolveTimeline(config: timelineConfig, for: now) else {
            delegate?.countdownDidUpdate("Lights Out")
            return
        }

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

    private func nextPhaseAfterIdle(_ t: Timeline) -> (String, Date) {
        if t.amber != t.winddown { return ("Amber", t.amber) }
        if t.winddown != t.lightsOut { return ("Wind-down", t.winddown) }
        return ("Lights out", t.lightsOut)
    }

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
