import SwiftUI
import LightsOutCore

/// "Enter Lights Out now" sheet: applies lightsOut immediately (and runs the grayscale
/// Shortcut if one is configured) after a friction confirmation, so a user can
/// deliberately start the bedtime routine early.
///
/// Unlike the override flow, this *adds* restrictions — so the friction is lower
/// (no phrase to type), it's just a confirmation step.
struct ManualLightsOutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: LightsOutConfig = ConfigStore.load()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.indigo)

                Text("Start Lights Out now?")
                    .font(.title).bold()

                Text("This will immediately apply your lights-out restrictions, run the " +
                     "grayscale Shortcut (if configured), and keep restrictions on until " +
                     "morning reset.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                Button {
                    enterLightsOut()
                } label: {
                    Label("Yes, good night", systemImage: "moon.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)

                Button("Not yet", role: .cancel) { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Manual Lights Out")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func enterLightsOut() {
        // Apply the strictest shield immediately.
        PhaseApplier.apply(phase: .lightsOut)

        // Kick off the grayscale shortcut if the user has configured one.
        if let name = config.grayscaleOnShortcutName, !name.isEmpty {
            ShortcutRunner.runShortcut(named: name)
        }
        dismiss()
    }
}
