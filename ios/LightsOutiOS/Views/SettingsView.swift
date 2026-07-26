import SwiftUI
import FamilyControls
import LightsOutCore

/// User settings. All writes go through `ConfigStore.save` + `ScheduleManager.reschedule`
/// so schedule changes take effect immediately.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var config: LightsOutConfig = ConfigStore.load()
    @State private var selection: FamilyActivitySelection = ActivitySelectionStore.load()
    @State private var showingAppPicker = false
    @State private var showingGrayscaleWizard = false

    var body: some View {
        NavigationStack {
            Form {
                phasesSection
                appsSection
                grayscaleSection
                frictionSection
                advancedSection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveAndDismiss() }
                        .bold()
                        .disabled(!config.validate().isEmpty)
                }
            }
            .familyActivityPicker(isPresented: $showingAppPicker, selection: $selection)
            .sheet(isPresented: $showingGrayscaleWizard) {
                GrayscaleSetupView()
            }
        }
    }

    // MARK: - Sections

    private var phasesSection: some View {
        Section {
            timePicker("Amber", selection: $config.amberTime)
            timePicker("Wind Down", selection: $config.winddownTime)
            timePicker("Lights Out", selection: $config.lightsOutTime)
            timePicker("Morning Reset", selection: $config.morningResetTime)

            ForEach(config.validate(), id: \.self) { error in
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Phase Times")
        } footer: {
            Text("Each phase starts at its time and continues until the next phase. " +
                 "Lights Out ends at Morning Reset.")
        }
    }

    private var appsSection: some View {
        Section {
            Button {
                showingAppPicker = true
            } label: {
                HStack {
                    Text("Select apps and domains")
                    Spacer()
                    Text(selectionSummary)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("What to restrict")
        } footer: {
            Text("Tap to open the system picker. Apps are restricted by category and by " +
                 "token; iOS does not let us show the list of individual apps you chose.")
        }
    }

    private var grayscaleSection: some View {
        Section {
            Button("Set up grayscale automation") {
                showingGrayscaleWizard = true
            }
        } header: {
            Text("Grayscale")
        } footer: {
            Text("iOS does not allow apps to toggle Color Filters directly. Lights Out " +
                 "calls a Shortcut you create, which can toggle grayscale on your behalf.")
        }
    }

    private var frictionSection: some View {
        Section {
            ForEach(Array(config.frictionDelaysSeconds.enumerated()), id: \.offset) { index, _ in
                Stepper(
                    value: Binding(
                        get: { config.frictionDelaysSeconds[index] },
                        set: { config.frictionDelaysSeconds[index] = $0 }
                    ),
                    in: 10...3600,
                    step: 30
                ) {
                    Text("Step \(index + 1): \(config.frictionDelaysSeconds[index])s")
                }
            }
        } header: {
            Text("Friction delays")
        } footer: {
            Text("Each override adds a timer before you can type the phrase. " +
                 "Longer timers = harder to cave.")
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            Button("Re-run onboarding", role: .destructive) {
                appState.resetOnboarding()
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func timePicker(_ label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: { dateFromTimeString(selection.wrappedValue) },
                    set: { selection.wrappedValue = timeStringFromDate($0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    private var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        let webs = selection.webDomainTokens.count
        if apps + cats + webs == 0 { return "None" }
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) apps") }
        if cats > 0 { parts.append("\(cats) categories") }
        if webs > 0 { parts.append("\(webs) domains") }
        return parts.joined(separator: ", ")
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

    private func saveAndDismiss() {
        guard config.validate().isEmpty else { return }
        ConfigStore.save(config)
        ActivitySelectionStore.save(selection)
        ScheduleManager.reschedule(using: config)
        dismiss()
    }
}
