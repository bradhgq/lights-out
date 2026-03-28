import SwiftUI

struct SettingsView: View {
    let configManager: ConfigManager
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var amberTime: String
    @State private var winddownTime: String
    @State private var lightsOutTime: String
    @State private var morningResetTime: String
    @State private var blockedBundleIDs: [String]
    @State private var whitelistedBundleIDs: [String]
    @State private var blockedDomains: [String]
    @State private var checklist: [String]
    @State private var frictionDelays: [Int]
    @State private var enableShortcutTrigger: Bool
    @State private var shortcutName: String
    @State private var showCountdownInMenuBar: Bool

    @State private var showAppPicker = false
    @State private var appPickerTarget: AppPickerTarget = .blocked
    @State private var validationErrors: [String] = []
    @State private var newDomain: String = ""
    @State private var newChecklistItem: String = ""
    @State private var newFrictionDelay: String = ""
    @State private var isDirty = false

    enum AppPickerTarget {
        case blocked, whitelisted
    }

    init(configManager: ConfigManager, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.configManager = configManager
        self.onSave = onSave
        self.onCancel = onCancel
        let c = configManager.config
        _amberTime = State(initialValue: c.amberTime)
        _winddownTime = State(initialValue: c.winddownTime)
        _lightsOutTime = State(initialValue: c.lightsOutTime)
        _morningResetTime = State(initialValue: c.morningResetTime)
        _blockedBundleIDs = State(initialValue: c.blockedAppBundleIDs ?? [])
        _whitelistedBundleIDs = State(initialValue: c.whitelistedAppBundleIDs ?? [])
        _blockedDomains = State(initialValue: c.blockedDomains)
        _checklist = State(initialValue: c.checklist)
        _frictionDelays = State(initialValue: c.frictionDelaysSeconds)
        _enableShortcutTrigger = State(initialValue: c.enableShortcutTrigger)
        _shortcutName = State(initialValue: c.shortcutName)
        _showCountdownInMenuBar = State(initialValue: c.showCountdownInMenuBar)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                scheduleTab
                    .tabItem { Label("Schedule", systemImage: "clock") }

                appsTab
                    .tabItem { Label("Apps", systemImage: "app.badge") }

                domainsTab
                    .tabItem { Label("Domains", systemImage: "globe") }

                checklistTab
                    .tabItem { Label("Checklist", systemImage: "checklist") }

                advancedTab
                    .tabItem { Label("Advanced", systemImage: "gearshape") }
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isDirty)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 540)
        .sheet(isPresented: $showAppPicker) {
            AppPickerSheet(
                scanner: configManager.scanner,
                excludedBundleIDs: Set(blockedBundleIDs + whitelistedBundleIDs),
                onSelect: { info in
                    switch appPickerTarget {
                    case .blocked:
                        blockedBundleIDs.append(info.id)
                    case .whitelisted:
                        whitelistedBundleIDs.append(info.id)
                    }
                    showAppPicker = false
                    isDirty = true
                },
                onCancel: { showAppPicker = false }
            )
        }
    }

    // MARK: - Schedule Tab

    private var scheduleTab: some View {
        Form {
            Section("Phase Times") {
                TimeField(label: "Amber", time: $amberTime)
                TimeField(label: "Wind-down", time: $winddownTime)
                TimeField(label: "Lights Out", time: $lightsOutTime)
                TimeField(label: "Morning Reset", time: $morningResetTime)
            }

            Section("Display") {
                Toggle("Show countdown in menu bar", isOn: $showCountdownInMenuBar)
            }

            if !validationErrors.isEmpty {
                Section("Validation") {
                    ForEach(validationErrors, id: \.self) { error in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: amberTime) { _ in isDirty = true }
        .onChange(of: winddownTime) { _ in isDirty = true }
        .onChange(of: lightsOutTime) { _ in isDirty = true }
        .onChange(of: morningResetTime) { _ in isDirty = true }
        .onChange(of: showCountdownInMenuBar) { _ in isDirty = true }
    }

    // MARK: - Apps Tab

    private var appsTab: some View {
        Form {
            Section("Blocked Apps") {
                bundleIDList(ids: $blockedBundleIDs)

                Button {
                    appPickerTarget = .blocked
                    showAppPicker = true
                } label: {
                    Label("Add App...", systemImage: "plus")
                }
            }

            Section("Whitelisted Apps") {
                bundleIDList(ids: $whitelistedBundleIDs)

                Button {
                    appPickerTarget = .whitelisted
                    showAppPicker = true
                } label: {
                    Label("Add App...", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func bundleIDList(ids: Binding<[String]>) -> some View {
        ForEach(ids.wrappedValue, id: \.self) { bundleID in
            HStack(spacing: 12) {
                if let appInfo = configManager.scanner.appInfo(forBundleID: bundleID) {
                    Image(nsImage: appInfo.icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                    Text(appInfo.displayName)
                } else {
                    Image(systemName: "app")
                        .frame(width: 32, height: 32)
                    Text(bundleID)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    ids.wrappedValue.removeAll { $0 == bundleID }
                    isDirty = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Domains Tab

    private var domainsTab: some View {
        Form {
            Section("Blocked Domains") {
                ForEach(blockedDomains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                        Spacer()
                        Button(role: .destructive) {
                            blockedDomains.removeAll { $0 == domain }
                            isDirty = true
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("e.g. youtube.com", text: $newDomain)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addDomain() }
                    Button("Add") { addDomain() }
                        .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Checklist Tab

    private var checklistTab: some View {
        Form {
            Section("Bedtime Checklist") {
                ForEach(Array(checklist.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(item)
                        Spacer()
                        Button(role: .destructive) {
                            checklist.remove(at: index)
                            isDirty = true
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("e.g. Brush teeth", text: $newChecklistItem)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addChecklistItem() }
                    Button("Add") { addChecklistItem() }
                        .disabled(newChecklistItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        Form {
            Section("Friction Delays (seconds)") {
                ForEach(Array(frictionDelays.enumerated()), id: \.offset) { index, delay in
                    HStack {
                        Text("\(delay)s")
                            .monospacedDigit()
                        if index < frictionDelays.count - 1 {
                            Text("\u{2192}")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            frictionDelays.remove(at: index)
                            isDirty = true
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("e.g. 300", text: $newFrictionDelay)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onSubmit { addFrictionDelay() }
                    Text("sec")
                        .foregroundColor(.secondary)
                    Button("Add") { addFrictionDelay() }
                        .disabled(Int(newFrictionDelay) == nil)
                }

                Text("Each blocked app gets this many overrides before being fully blocked.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Shortcuts Integration") {
                Toggle("Trigger macOS Shortcut at Lights Out", isOn: $enableShortcutTrigger)
                    .onChange(of: enableShortcutTrigger) { _ in isDirty = true }

                if enableShortcutTrigger {
                    HStack {
                        Text("Shortcut name:")
                        TextField("Bedtime", text: $shortcutName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: shortcutName) { _ in isDirty = true }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func save() {
        var config = configManager.config
        config.amberTime = amberTime
        config.winddownTime = winddownTime
        config.lightsOutTime = lightsOutTime
        config.morningResetTime = morningResetTime
        config.blockedAppBundleIDs = blockedBundleIDs
        config.whitelistedAppBundleIDs = whitelistedBundleIDs
        config.blockedDomains = blockedDomains
        config.checklist = checklist
        config.frictionDelaysSeconds = frictionDelays
        config.enableShortcutTrigger = enableShortcutTrigger
        config.shortcutName = shortcutName
        config.showCountdownInMenuBar = showCountdownInMenuBar

        validationErrors = config.validate()
        if !validationErrors.isEmpty { return }

        configManager.config = config
        configManager.save()
        onSave()
    }

    private func addDomain() {
        let domain = newDomain.trimmingCharacters(in: .whitespaces).lowercased()
        guard !domain.isEmpty, !blockedDomains.contains(domain) else { return }
        blockedDomains.append(domain)
        newDomain = ""
        isDirty = true
    }

    private func addChecklistItem() {
        let item = newChecklistItem.trimmingCharacters(in: .whitespaces)
        guard !item.isEmpty else { return }
        checklist.append(item)
        newChecklistItem = ""
        isDirty = true
    }

    private func addFrictionDelay() {
        guard let seconds = Int(newFrictionDelay), seconds > 0 else { return }
        frictionDelays.append(seconds)
        newFrictionDelay = ""
        isDirty = true
    }
}

// MARK: - Time Field

struct TimeField: View {
    let label: String
    @Binding var time: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("00:00", text: $time)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    let scanner: InstalledAppScanner
    let excludedBundleIDs: Set<String>
    let onSelect: (InstalledAppInfo) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""

    private var filteredApps: [InstalledAppInfo] {
        let available = scanner.apps.filter { !excludedBundleIDs.contains($0.id) }
        if searchText.isEmpty { return available }
        return available.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
            || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select an App")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)
            }
            .padding()

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(filteredApps) { app in
                Button {
                    onSelect(app)
                } label: {
                    HStack(spacing: 12) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                        Text(app.displayName)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 440, height: 480)
    }
}
