import SwiftUI

struct SettingsView: View {
    let configManager: ConfigManager
    let onSave: () -> Void

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

    enum AppPickerTarget {
        case blocked, whitelisted
    }

    init(configManager: ConfigManager, onSave: @escaping () -> Void) {
        self.configManager = configManager
        self.onSave = onSave
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
        .padding()
        .frame(minWidth: 480, minHeight: 500)
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
                    save()
                },
                onCancel: { showAppPicker = false }
            )
        }
    }

    // MARK: - Schedule Tab

    private var scheduleTab: some View {
        Form {
            Section("Phase Times") {
                TimeField(label: "Amber", time: $amberTime, onCommit: save)
                TimeField(label: "Wind-down", time: $winddownTime, onCommit: save)
                TimeField(label: "Lights Out", time: $lightsOutTime, onCommit: save)
                TimeField(label: "Morning Reset", time: $morningResetTime, onCommit: save)
            }

            Section("Display") {
                Toggle("Show countdown in menu bar", isOn: $showCountdownInMenuBar)
                    .onChange(of: showCountdownInMenuBar) { _ in save() }
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
            HStack {
                let displayName = configManager.scanner.displayName(forBundleID: bundleID)
                VStack(alignment: .leading) {
                    Text(displayName ?? bundleID)
                        .font(.body)
                    if displayName != nil {
                        Text(bundleID)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(role: .destructive) {
                    ids.wrappedValue.removeAll { $0 == bundleID }
                    save()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
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
                            save()
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
                            save()
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
                            Text("→")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            frictionDelays.remove(at: index)
                            save()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("seconds", text: $newFrictionDelay)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onSubmit { addFrictionDelay() }
                    Button("Add") { addFrictionDelay() }
                        .disabled(Int(newFrictionDelay) == nil)
                }

                Text("Each blocked app gets this many overrides before being fully blocked.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Shortcuts Integration") {
                Toggle("Trigger macOS Shortcut at Lights Out", isOn: $enableShortcutTrigger)
                    .onChange(of: enableShortcutTrigger) { _ in save() }

                if enableShortcutTrigger {
                    HStack {
                        Text("Shortcut name:")
                        TextField("Bedtime", text: $shortcutName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { save() }
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

        configManager.config = config
        configManager.save()
        onSave()
    }

    private func addDomain() {
        let domain = newDomain.trimmingCharacters(in: .whitespaces).lowercased()
        guard !domain.isEmpty, !blockedDomains.contains(domain) else { return }
        blockedDomains.append(domain)
        newDomain = ""
        save()
    }

    private func addChecklistItem() {
        let item = newChecklistItem.trimmingCharacters(in: .whitespaces)
        guard !item.isEmpty else { return }
        checklist.append(item)
        newChecklistItem = ""
        save()
    }

    private func addFrictionDelay() {
        guard let seconds = Int(newFrictionDelay), seconds > 0 else { return }
        frictionDelays.append(seconds)
        newFrictionDelay = ""
        save()
    }
}

// MARK: - Time Field

struct TimeField: View {
    let label: String
    @Binding var time: String
    let onCommit: () -> Void

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("HH:mm", text: $time)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .multilineTextAlignment(.center)
                .onSubmit { onCommit() }
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
                    HStack {
                        VStack(alignment: .leading) {
                            Text(app.displayName)
                                .font(.body)
                            Text(app.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 440, height: 480)
    }
}
