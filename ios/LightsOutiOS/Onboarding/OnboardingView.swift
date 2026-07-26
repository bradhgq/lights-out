import SwiftUI
import FamilyControls
import LightsOutCore

/// First-launch onboarding. Walks the user through:
///   1. What the app does
///   2. Granting Screen Time authorization (required)
///   3. Picking apps/domains to restrict
///   4. Setting phase times
///   5. Setting up the grayscale Shortcut (optional, skippable)
///   6. Done — writes config and registers schedules
///
/// After step 6, `AppState.needsOnboarding` is set to false and `RootView` swaps to the
/// dashboard. The user can re-run onboarding anytime from Settings.
struct OnboardingView: View {
    @EnvironmentObject var authorization: AuthorizationManager
    @EnvironmentObject var appState: AppState

    @State private var step: Step = .welcome
    @State private var config: LightsOutConfig = ConfigStore.load()
    @State private var selection: FamilyActivitySelection = ActivitySelectionStore.load()

    private enum Step: Int, CaseIterable {
        case welcome, authorization, pickApps, phaseTimes, grayscale, done
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome:       welcomeStep
                case .authorization: authorizationStep
                case .pickApps:      pickAppsStep
                case .phaseTimes:    phaseTimesStep
                case .grayscale:     grayscaleStep
                case .done:          doneStep
                }
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 72))
                .foregroundStyle(.indigo)

            Text("Lights Out")
                .font(.largeTitle).bold()
            Text("Adds real friction to late-night app use. At the times you set, selected " +
                 "apps are shielded. Overriding requires typing a phrase — slow enough to " +
                 "remember you meant to go to sleep.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Begin") {
                advance()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var authorizationStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 72))
                .foregroundStyle(.blue)
            Text("Grant Screen Time")
                .font(.title).bold()
            Text("Lights Out uses Apple's Screen Time API to shield apps. You'll see a " +
                 "system prompt — tap Continue, then Allow.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            if authorization.status == .approved {
                Label("Screen Time authorized", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Button("Continue") { advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                Button("Grant authorization") {
                    Task { await authorization.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if authorization.status == .denied {
                    Text("Authorization was denied. Open Settings → Screen Time to grant.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var pickAppsStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 72))
                .foregroundStyle(.purple)
            Text("Pick what to restrict")
                .font(.title).bold()
            Text("Choose the apps, categories, and web domains to restrict during your " +
                 "wind-down and lights-out hours.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Text(selectionSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Open picker") {
                showingPicker = true
            }
            .buttonStyle(.bordered)

            Button("Continue") { advance() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectionTotalCount == 0)
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
    }

    @State private var showingPicker = false

    private var phaseTimesStep: some View {
        Form {
            Section("Phase times") {
                timePicker("Amber", $config.amberTime)
                timePicker("Wind Down", $config.winddownTime)
                timePicker("Lights Out", $config.lightsOutTime)
                timePicker("Morning Reset", $config.morningResetTime)

                ForEach(config.validate(), id: \.self) { error in
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                Button("Continue") { advance() }
                    .disabled(!config.validate().isEmpty)
            }
        }
    }

    private var grayscaleStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 72))
                .foregroundStyle(.gray)
            Text("Set up grayscale")
                .font(.title).bold()
            Text("iOS does not allow apps to toggle Color Filters directly, so Lights Out " +
                 "asks a Shortcut you create to do it. We'll walk you through it — or you " +
                 "can skip and set it up later.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Set up now") {
                showingWizard = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip for now") { advance() }
                .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showingWizard) {
            GrayscaleSetupView(onDone: { advance() })
        }
    }

    @State private var showingWizard = false

    private var doneStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("All set")
                .font(.title).bold()
            Text("Your phases are scheduled. You can tweak anything in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Finish") {
                complete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Helpers

    private func timePicker(_ label: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: { dateFromTimeString(binding.wrappedValue) },
                    set: { binding.wrappedValue = timeStringFromDate($0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    private func dateFromTimeString(_ s: String) -> Date {
        guard let (h, m) = LightsOutCore.parseTime(s) else { return Date() }
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = h
        c.minute = m
        return Calendar.current.date(from: c) ?? Date()
    }

    private func timeStringFromDate(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private var selectionTotalCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    private var selectionSummary: String {
        if selectionTotalCount == 0 { return "Nothing selected yet." }
        return "\(selectionTotalCount) item(s) selected."
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else {
            complete()
            return
        }
        step = next
    }

    private func complete() {
        ConfigStore.save(config)
        ActivitySelectionStore.save(selection)
        ScheduleManager.reschedule(using: config)
        appState.needsOnboarding = false
    }
}
