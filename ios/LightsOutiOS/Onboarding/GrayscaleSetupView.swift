import SwiftUI
import LightsOutCore

/// Walks the user through creating two personal automations in Shortcuts:
///   1. A time-of-day automation at `amberTime` → Set Color Filters → On
///   2. A time-of-day automation at `morningResetTime` → Set Color Filters → Off
///
/// We can't create these automations programmatically — Shortcuts has no such API —
/// so the wizard explains each step clearly and deep-links into Shortcuts at the
/// right moments. We also expose a "Test" button that tries to run a named Shortcut
/// the user has already created, so the user can verify their setup.
///
/// An experienced user might instead create two regular Shortcuts ("Lights Out —
/// Grayscale On" / "...Off") and let the app trigger them directly via
/// `ShortcutRunner.runShortcut(named:)`. Both paths are supported.
struct GrayscaleSetupView: View {

    /// Called when the wizard completes (or is dismissed after "Done"). Used by
    /// onboarding to advance to the next step.
    var onDone: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var config: LightsOutConfig = ConfigStore.load()
    @State private var onName: String
    @State private var offName: String

    init(onDone: (() -> Void)? = nil) {
        self.onDone = onDone
        let loaded = ConfigStore.load()
        _onName = State(initialValue:
            loaded.grayscaleOnShortcutName
            ?? LightsOutConfig.defaults.grayscaleOnShortcutName
            ?? "Lights Out — Grayscale On")
        _offName = State(initialValue:
            loaded.grayscaleOffShortcutName
            ?? LightsOutConfig.defaults.grayscaleOffShortcutName
            ?? "Lights Out — Grayscale Off")
    }

    var body: some View {
        NavigationStack {
            Form {
                instructionsSection
                namesSection
                testSection
            }
            .navigationTitle("Grayscale")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { saveAndFinish() }
                        .bold()
                }
            }
        }
    }

    // MARK: - Sections

    private var instructionsSection: some View {
        Section {
            Text("1. Open Shortcuts.\n" +
                 "2. Tap \u{201C}+\u{201D} to create a new Shortcut.\n" +
                 "3. Add the \u{201C}Set Color Filters\u{201D} action, set it to On.\n" +
                 "4. Name the Shortcut exactly as below.\n" +
                 "5. Repeat for the Off version.\n\n" +
                 "Optional: turn each into a Personal Automation triggered at the matching " +
                 "phase time — that way grayscale switches automatically, even when the " +
                 "Lights Out app isn't open.")
                .font(.callout)

            Button {
                ShortcutRunner.openShortcutsApp()
            } label: {
                Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
            }
        } header: {
            Text("Create the Shortcuts")
        } footer: {
            Text("Why this is manual: iOS does not expose Color Filters to apps. " +
                 "Shortcuts does, so we delegate.")
        }
    }

    private var namesSection: some View {
        Section {
            LabeledContent("Turn grayscale ON") {
                TextField("Shortcut name", text: $onName)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Turn grayscale OFF") {
                TextField("Shortcut name", text: $offName)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Shortcut names")
        } footer: {
            Text("These must exactly match the Shortcut names you created in Shortcuts.")
        }
    }

    private var testSection: some View {
        Section {
            Button {
                ShortcutRunner.runShortcut(named: onName)
            } label: {
                Label("Test \u{201C}On\u{201D} shortcut", systemImage: "play.fill")
            }
            Button {
                ShortcutRunner.runShortcut(named: offName)
            } label: {
                Label("Test \u{201C}Off\u{201D} shortcut", systemImage: "play")
            }
        } header: {
            Text("Verify")
        } footer: {
            Text("Tapping Test should cause Shortcuts to open and run the named Shortcut. " +
                 "If nothing happens, check that the names match exactly.")
        }
    }

    // MARK: - Save

    private func saveAndFinish() {
        config.grayscaleOnShortcutName = onName
        config.grayscaleOffShortcutName = offName
        ConfigStore.save(config)
        dismiss()
        onDone?()
    }
}
