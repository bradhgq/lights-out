import SwiftUI
import ManagedSettings
import LightsOutCore

/// Full-screen friction sheet presented when the shield-action extension sends us a
/// `lightsout://override` URL (or the user taps "Enter Lights Out now" and wants to
/// bail out).
///
/// Flow:
///  1. A forced wait timer (from `LightsOutConfig.frictionDelaysSeconds[0]`) runs.
///  2. User must type a randomly-chosen wind-down phrase *exactly*.
///  3. User picks an override duration (short, e.g. 5 or 15 minutes).
///  4. We temporarily remove restrictions on the relevant store for that duration.
///
/// If the phase is `.lightsOut`, we use the emergency path (a harder phrase + a random
/// challenge string), mirroring macOS's `BlockedOverlayView`.
struct FrictionOverrideSheet: View {
    /// Phase store name from the URL (e.g. "phase.lightsOut").
    let phaseStoreName: String

    @Environment(\.dismiss) private var dismiss

    @State private var config: LightsOutConfig = ConfigStore.load()

    @State private var remainingWait: Int
    @State private var typedPhrase: String = ""
    @State private var typedChallenge: String = ""
    @State private var phrase: String
    @State private var challenge: String

    @FocusState private var phraseFieldFocused: Bool
    @FocusState private var challengeFieldFocused: Bool

    private let isEmergency: Bool

    init(phaseStoreName: String) {
        self.phaseStoreName = phaseStoreName

        let loaded = ConfigStore.load()
        let isLightsOut = (phaseStoreName == PhaseStoreName.lightsOut)

        self.isEmergency = isLightsOut
        _remainingWait = State(initialValue: loaded.frictionDelaysSeconds.first ?? 60)
        _phrase = State(initialValue: isLightsOut
            ? FrictionText.randomEmergencyPhrase()
            : FrictionText.randomWindDownPhrase())
        _challenge = State(initialValue: isLightsOut
            ? FrictionText.generateRandomChallenge(length: 20)
            : "")
    }

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 24) {
                Text(isEmergency ? "Emergency Override" : "Are you sure?")
                    .font(.largeTitle).bold()
                    .foregroundStyle(isEmergency ? .red : .orange)

                if remainingWait > 0 {
                    waitView
                } else {
                    typingView
                }

                Spacer()

                Button("Cancel — go to bed", role: .cancel) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding()
            .foregroundStyle(.white)
        }
        .onReceive(tick) { _ in
            if remainingWait > 0 { remainingWait -= 1 }
        }
    }

    // MARK: - States

    private var waitView: some View {
        VStack(spacing: 12) {
            Text("Is it worth it?")
                .font(.title3)
                .foregroundStyle(.orange)
            Text(formatMMSS(remainingWait))
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
            Text("Wait for the timer to finish.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var typingView: some View {
        VStack(spacing: 16) {
            Text("Type the phrase below, exactly:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Text("\u{201C}\(phrase)\u{201D}")
                .font(.body)
                .italic()
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Type here…", text: $typedPhrase, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($phraseFieldFocused)
                .onAppear { phraseFieldFocused = true }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(.black)

            if FrictionText.matches(typed: typedPhrase, challenge: phrase) {
                if isEmergency {
                    challengeEntry
                } else {
                    durationButtons
                }
            }
        }
    }

    private var challengeEntry: some View {
        VStack(spacing: 12) {
            Text("Now type this random string exactly:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Text(challenge)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .textSelection(.disabled)

            TextField("", text: $typedChallenge)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .focused($challengeFieldFocused)
                .onAppear { challengeFieldFocused = true }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(.black)

            if typedChallenge == challenge {
                Button("Grant emergency override (15 min)") {
                    grantOverride(minutes: 15)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    private var durationButtons: some View {
        HStack(spacing: 12) {
            ForEach([5, 15], id: \.self) { minutes in
                Button("\(minutes) min") {
                    grantOverride(minutes: minutes)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }

    // MARK: - Actions

    /// Clear the relevant phase's store for `minutes` minutes, then reapply.
    ///
    /// This is per-phase, not per-app: granting an override lifts the full shield for
    /// that phase. A future enhancement could target a single application token by
    /// removing it from the store's shield set and restoring it after the timer.
    private func grantOverride(minutes: Int) {
        guard let phase = phaseFromStoreName(phaseStoreName) else { dismiss(); return }

        // Clear the store now.
        PhaseApplier.clear(phase: phase)

        // Schedule a re-apply after `minutes`.
        let deadline = DispatchTime.now() + .seconds(minutes * 60)
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            // Only re-apply if we're still in or past this phase. If the user slept past
            // morning-reset, the monitor extension will have run `intervalDidEnd` and the
            // phase won't be active — re-applying would be wrong.
            let currentlyActive = PhaseState.computedPhase()
            if currentlyActive == phase
                || phase == .amber && [.windDown, .lightsOut].contains(currentlyActive)
                || phase == .windDown && currentlyActive == .lightsOut
            {
                PhaseApplier.apply(phase: phase)
            }
        }

        dismiss()
    }

    private func phaseFromStoreName(_ name: String) -> Phase? {
        switch name {
        case PhaseStoreName.amber:     return .amber
        case PhaseStoreName.windDown:  return .windDown
        case PhaseStoreName.lightsOut: return .lightsOut
        default: return nil
        }
    }

    private func formatMMSS(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
