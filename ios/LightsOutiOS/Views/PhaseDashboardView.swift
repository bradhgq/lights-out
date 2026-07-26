import SwiftUI
import LightsOutCore

/// Main screen shown after onboarding. Displays the current phase, a countdown to
/// the next phase boundary, and quick access to settings + manual "Enter Lights Out now".
struct PhaseDashboardView: View {
    @State private var currentPhase: Phase = PhaseState.computedPhase()
    @State private var timeline: Timeline? = PhaseState.timeline()
    @State private var now: Date = Date()
    @State private var showingSettings = false
    @State private var showingManualTrigger = false

    /// Timer updates every second so the countdown is live. Invalidated by SwiftUI
    /// automatically when the view disappears.
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                phaseHeader
                countdownView
                Spacer()
                manualTriggerButton
            }
            .padding()
            .navigationTitle("Lights Out")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingManualTrigger) {
                ManualLightsOutSheet()
            }
        }
        .onReceive(tick) { date in
            now = date
            // Refresh computed phase/timeline every tick; cheap (pure math, no IO).
            currentPhase = PhaseState.computedPhase(at: date)
            timeline = PhaseState.timeline(at: date)
        }
    }

    // MARK: - Subviews

    private var phaseHeader: some View {
        VStack(spacing: 8) {
            Text(phaseLabel(currentPhase))
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(phaseColor(currentPhase))
            Text(phaseDescription(currentPhase))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var countdownView: some View {
        Group {
            if let (label, seconds) = nextBoundary() {
                VStack(spacing: 4) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCountdown(seconds))
                        .font(.system(size: 64, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }
            }
        }
    }

    private var manualTriggerButton: some View {
        Button {
            showingManualTrigger = true
        } label: {
            Label("Enter Lights Out now", systemImage: "moon.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
    }

    // MARK: - Helpers

    private func phaseLabel(_ phase: Phase) -> String {
        switch phase {
        case .idle:      return "Daytime"
        case .amber:     return "Amber"
        case .windDown:  return "Wind Down"
        case .lightsOut: return "Lights Out"
        }
    }

    private func phaseColor(_ phase: Phase) -> Color {
        switch phase {
        case .idle:      return .primary
        case .amber:     return .orange
        case .windDown:  return .red
        case .lightsOut: return .indigo
        }
    }

    private func phaseDescription(_ phase: Phase) -> String {
        switch phase {
        case .idle:      return "No restrictions active."
        case .amber:     return "Wind-down is approaching. Web domains are restricted."
        case .windDown:  return "Apps are resting. Friction required to override."
        case .lightsOut: return "Selected apps are blocked until morning."
        }
    }

    /// Next phase boundary and seconds remaining. `nil` if no timeline could be resolved.
    private func nextBoundary() -> (label: String, seconds: Int)? {
        guard let t = timeline else { return nil }
        let upcoming: [(String, Date)] = [
            ("Until Amber", t.amber),
            ("Until Wind Down", t.winddown),
            ("Until Lights Out", t.lightsOut),
            ("Until Morning", t.nextMorning),
        ]
        for (label, date) in upcoming where date > now {
            return (label, Int(date.timeIntervalSince(now)))
        }
        return nil
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}
