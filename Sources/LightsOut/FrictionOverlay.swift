import AppKit
import SwiftUI

/// Borderless window that can become key (needed for text input).
private class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class FrictionOverlayController {
    private var window: NSWindow?

    var isShowing: Bool { window != nil }

    /// Show the wind-down friction overlay. `onComplete` receives the chosen duration in minutes, or nil if cancelled.
    func show(delay: Int, appName: String, onComplete: @escaping (Int?) -> Void) {
        guard window == nil else { return }

        let overlayView = FrictionOverlayView(
            delaySeconds: delay,
            appName: appName,
            durationChoices: Constants.overrideDurationChoices,
            onAllow: { [weak self] minutes in
                self?.dismiss()
                onComplete(minutes)
            },
            onCancel: { [weak self] in
                self?.dismiss()
                onComplete(nil)
            }
        )

        guard let screen = NSScreen.main else { return }
        let win = KeyableWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.level = .init(Int(CGShieldingWindowLevel()))
        win.isOpaque = false
        win.backgroundColor = .clear
        win.contentView = NSHostingView(rootView: overlayView)
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.makeKeyAndOrderFront(nil)

        // Activate our app so the window can receive keyboard input
        NSApplication.shared.activate(ignoringOtherApps: true)

        self.window = win
    }

    func showBlocked(appName: String, onEmergencyOverride: (() -> Void)? = nil) {
        guard window == nil else { return }

        let blockedView = BlockedOverlayView(
            appName: appName,
            onDismiss: { [weak self] in
                self?.dismiss()
            },
            onEmergencyOverride: onEmergencyOverride.map { handler in
                { [weak self] in
                    self?.dismiss()
                    handler()
                }
            }
        )

        guard let screen = NSScreen.main else { return }
        let win = KeyableWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.level = .init(Int(CGShieldingWindowLevel()))
        win.isOpaque = false
        win.backgroundColor = .clear
        win.contentView = NSHostingView(rootView: blockedView)
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.makeKeyAndOrderFront(nil)

        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = win
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - SwiftUI Views

struct FrictionOverlayView: View {
    let delaySeconds: Int
    let appName: String
    let durationChoices: [Int] // minutes
    let onAllow: (Int) -> Void // passes chosen duration in minutes
    let onCancel: () -> Void

    @State private var remainingSeconds: Int
    @State private var typedPhrase: String = ""
    @State private var challengePhrase: String = Constants.randomWindDownPhrase()
    @FocusState private var textFieldFocused: Bool

    init(delaySeconds: Int, appName: String, durationChoices: [Int], onAllow: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.delaySeconds = delaySeconds
        self.appName = appName
        self.durationChoices = durationChoices
        self.onAllow = onAllow
        self.onCancel = onCancel
        self._remainingSeconds = State(initialValue: delaySeconds)
    }

    private var phraseMatches: Bool {
        typedPhrase.trimmingCharacters(in: .whitespaces) == challengePhrase
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("You're choosing to stay up.")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                Text("You tried to open \(appName) during wind-down.")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))

                if remainingSeconds > 0 {
                    Text("Is it worth it?")
                        .font(.title3)
                        .foregroundColor(.orange)

                    Text("\(formatTime(remainingSeconds))")
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)

                    Text("Wait for the timer to finish")
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("Type the phrase below exactly:")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))

                    Text("\"\(challengePhrase)\"")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.orange)
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    TextField("Type here...", text: $typedPhrase)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 500)
                        .font(.title3)
                        .focused($textFieldFocused)
                        .onAppear { textFieldFocused = true }

                    if phraseMatches {
                        Text("How long do you need?")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))

                        HStack(spacing: 16) {
                            ForEach(durationChoices, id: \.self) { minutes in
                                Button("\(minutes) minutes") {
                                    onAllow(minutes)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }
                        }
                    }
                }

                Button("Cancel — Go to bed") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.white)
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            startTimer()
        }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct BlockedOverlayView: View {
    let appName: String
    let onDismiss: () -> Void
    let onEmergencyOverride: (() -> Void)?

    @State private var showEmergency = false
    @State private var typedPhrase: String = ""
    @State private var typedRandom: String = ""
    @State private var challengePhrase: String = Constants.randomEmergencyPhrase()
    @State private var randomChallenge: String = Constants.generateRandomChallenge(length: 20)
    @FocusState private var phraseFieldFocused: Bool
    @FocusState private var randomFieldFocused: Bool

    private var phraseMatches: Bool {
        typedPhrase.trimmingCharacters(in: .whitespaces) == challengePhrase
    }
    private var randomMatches: Bool {
        typedRandom == randomChallenge
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("Blocked Until Morning")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.red)

                Text("\(appName) is not available right now.")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))

                Text("You've used all your overrides. Go to bed.")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))

                if !showEmergency {
                    HStack(spacing: 20) {
                        Button("OK") {
                            onDismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.gray)

                        if onEmergencyOverride != nil {
                            Button("Emergency Override") {
                                showEmergency = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red.opacity(0.6))
                        }
                    }
                    .padding(.top, 20)
                } else {
                    VStack(spacing: 20) {
                        Text("Type the phrase exactly:")
                            .foregroundColor(.white.opacity(0.7))

                        Text("\"\(challengePhrase)\"")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        TextField("Type phrase here...", text: $typedPhrase)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 500)
                            .focused($phraseFieldFocused)
                            .onAppear { phraseFieldFocused = true }

                        if phraseMatches {
                            Text("Now type this random string exactly:")
                                .foregroundColor(.white.opacity(0.7))

                            Text(randomChallenge)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                                .textSelection(.enabled)

                            TextField("Type random string here...", text: $typedRandom)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 500)
                                .font(.system(.body, design: .monospaced))
                                .focused($randomFieldFocused)
                                .onAppear { randomFieldFocused = true }
                        }

                        HStack(spacing: 20) {
                            Button("Cancel — Go to bed") {
                                onDismiss()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.white)

                            Button("Emergency Override") {
                                onEmergencyOverride?()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(!phraseMatches || !randomMatches)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
