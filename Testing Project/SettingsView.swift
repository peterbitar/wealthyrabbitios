import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: RabbitViewModel
    @StateObject private var pushManager = PushNotificationManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                WealthyRabbitTheme.burrowGradient
                    .ignoresSafeArea()

                List {
                    // Profile Section
                    Section(header: Text("Profile")) {
                        HStack {
                            Text("Name")
                                .font(WealthyRabbitTheme.bodyFont)
                            Spacer()
                            TextField("Your name", text: $viewModel.userSettings.userName)
                                .multilineTextAlignment(.trailing)
                                .font(WealthyRabbitTheme.bodyFont)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.6))

                    // Holdings Section
                    Section(header: Text("Portfolio")) {
                        NavigationLink(destination: HoldingsView(viewModel: viewModel)) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(WealthyRabbitTheme.mistBlue)
                                Text("Holdings & Accounts")
                                    .font(WealthyRabbitTheme.bodyFont)
                                Spacer()
                                Text("\(viewModel.userSettings.holdings.count)")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Toggle(isOn: $viewModel.userSettings.weeklyPortfolioSummary) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weekly Summary")
                                    .font(WealthyRabbitTheme.bodyFont)
                                Text("Get portfolio updates every Sunday")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(WealthyRabbitTheme.mossGreen)
                    }
                    .listRowBackground(Color.white.opacity(0.6))

                    // Calm Controls Section
                    Section(header: Text("Calm Controls")) {
                        NavigationLink(destination: NotificationSettingsView(viewModel: viewModel)) {
                            HStack {
                                Image(systemName: "bell.badge")
                                    .foregroundColor(WealthyRabbitTheme.apricot)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Mindful Notifications")
                                        .font(WealthyRabbitTheme.bodyFont)
                                    Text("\(viewModel.userSettings.notificationFrequency.rawValue) · \(viewModel.userSettings.notificationSensitivity.rawValue)")
                                        .font(WealthyRabbitTheme.captionFont)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.6))

                    // Backend Connection Section
                    Section(header: Text("Backend Connection")) {
                        HStack {
                            Image(systemName: viewModel.isBackendAvailable ? "cloud.fill" : "cloud.slash")
                                .foregroundColor(viewModel.isBackendAvailable ? WealthyRabbitTheme.mossGreen : .secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Backend Status")
                                    .font(WealthyRabbitTheme.bodyFont)
                                Text(viewModel.isBackendAvailable ? "Connected" : "Offline Mode")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if viewModel.isSyncing {
                                ProgressView()
                            } else {
                                Button("Sync") {
                                    Task {
                                        await viewModel.checkBackendAndSync()
                                    }
                                }
                                .font(WealthyRabbitTheme.captionFont)
                                .disabled(!viewModel.isBackendAvailable)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.6))

                    // Push Notifications Section
                    Section(header: Text("Push Notifications")) {
                        HStack {
                            Image(systemName: pushManager.notificationPermissionGranted ? "bell.fill" : "bell.slash")
                                .foregroundColor(pushManager.notificationPermissionGranted ? WealthyRabbitTheme.apricot : .secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notification Status")
                                    .font(WealthyRabbitTheme.bodyFont)
                                Text(pushManager.notificationPermissionGranted ? "Enabled" : "Disabled")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if !pushManager.notificationPermissionGranted {
                                Button("Enable") {
                                    Task {
                                        await pushManager.requestPermission()
                                    }
                                }
                                .font(WealthyRabbitTheme.captionFont)
                            }
                        }

                        if let token = pushManager.deviceToken {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Device Token")
                                    .font(WealthyRabbitTheme.bodyFont)
                                Text(String(token.prefix(20)) + "...")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Mode")
                                    .font(WealthyRabbitTheme.bodyFont)
                                Text("Simulated (Developer mode)")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.6))

                    // About Section
                    Section(header: Text("About")) {
                        HStack {
                            Text("Version")
                                .font(WealthyRabbitTheme.bodyFont)
                            Spacer()
                            Text("1.0")
                                .foregroundColor(.secondary)
                        }

                        Link(destination: URL(string: "https://example.com")!) {
                            HStack {
                                Text("Privacy Policy")
                                    .font(WealthyRabbitTheme.bodyFont)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.6))
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct NotificationSettingsView: View {
    @ObservedObject var viewModel: RabbitViewModel
    @State private var frequencySlider: Double = 1.0
    @State private var sensitivitySlider: Double = 1.0
    @State private var showTestFeedback = false
    @State private var lastNotifiedRabbit: String = ""

    var userSettings: UserSettings {
        viewModel.userSettings
    }

    var body: some View {
        ZStack {
            WealthyRabbitTheme.burrowGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: WealthyRabbitTheme.airySpacing) {
                    // Header
                    VStack(spacing: 8) {
                        Text("🧘")
                            .font(.system(size: 48))

                        Text("Mindful Notifications")
                            .font(WealthyRabbitTheme.titleFont)

                        Text("Control how often the rabbits reach out and how sensitive they are to market moves")
                            .font(WealthyRabbitTheme.bodyFont)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, WealthyRabbitTheme.airySpacing)
                    }
                    .padding(.top, WealthyRabbitTheme.normalSpacing)

                    // Mood Presets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Presets")
                            .font(WealthyRabbitTheme.captionFont)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 12) {
                            ForEach(MoodPreset.allCases, id: \.self) { preset in
                                MoodPresetButton(
                                    preset: preset,
                                    isSelected: isPresetSelected(preset),
                                    action: {
                                        userSettings.applyMoodPreset(preset)
                                        updateSliders()
                                    }
                                )
                            }
                        }
                    }
                    .calmCardStyle()
                    .padding(.horizontal, WealthyRabbitTheme.normalSpacing)

                    // Frequency Slider
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Frequency")
                            .font(WealthyRabbitTheme.headingFont)

                        Text("How often do you want the rabbits to reach out?")
                            .font(WealthyRabbitTheme.bodyFont)
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            HStack {
                                Text("Quiet")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Balanced")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Active")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $frequencySlider, in: 0...2, step: 1)
                                .tint(WealthyRabbitTheme.apricot)
                                .onChange(of: frequencySlider) { oldValue, newValue in
                                    updateFrequency()
                                }
                        }

                        Text(userSettings.notificationFrequency.description)
                            .font(WealthyRabbitTheme.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .calmCardStyle()
                    .padding(.horizontal, WealthyRabbitTheme.normalSpacing)

                    // Sensitivity Slider
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sensitivity")
                            .font(WealthyRabbitTheme.headingFont)

                        Text("How sensitive should they be to market moves?")
                            .font(WealthyRabbitTheme.bodyFont)
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            HStack {
                                Text("Calm")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Curious")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Alert")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $sensitivitySlider, in: 0...2, step: 1)
                                .tint(WealthyRabbitTheme.mistBlue)
                                .onChange(of: sensitivitySlider) { oldValue, newValue in
                                    updateSensitivity()
                                }
                        }

                        Text(userSettings.notificationSensitivity.description)
                            .font(WealthyRabbitTheme.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .calmCardStyle()
                    .padding(.horizontal, WealthyRabbitTheme.normalSpacing)

                    // Preview Box
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview")
                            .font(WealthyRabbitTheme.captionFont)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Text(userSettings.getPreviewNotification())
                            .font(WealthyRabbitTheme.bodyFont)
                            .padding(WealthyRabbitTheme.normalSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(WealthyRabbitTheme.linen)
                            .cornerRadius(12)
                    }
                    .calmCardStyle()
                    .padding(.horizontal, WealthyRabbitTheme.normalSpacing)

                    // Test Notification Button
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Mode")
                            .font(WealthyRabbitTheme.captionFont)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Button(action: {
                            let rabbitName = viewModel.sendTestNotification()
                            lastNotifiedRabbit = rabbitName
                            showTestFeedback = true

                            // Hide feedback after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                showTestFeedback = false
                            }
                        }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Send Test Notification")
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(WealthyRabbitTheme.normalSpacing)
                            .background(WealthyRabbitTheme.mistBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        if showTestFeedback {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(WealthyRabbitTheme.mossGreen)
                                Text("Test notification sent to \(lastNotifiedRabbit)! Check The Burrow to see the message.")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                            }
                            .transition(.opacity)
                        }
                    }
                    .calmCardStyle()
                    .padding(.horizontal, WealthyRabbitTheme.normalSpacing)
                    .padding(.bottom, WealthyRabbitTheme.airySpacing)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateSliders()
        }
    }

    func updateSliders() {
        frequencySlider = Double(NotificationFrequency.allCases.firstIndex(of: userSettings.notificationFrequency) ?? 1)
        sensitivitySlider = Double(NotificationSensitivity.allCases.firstIndex(of: userSettings.notificationSensitivity) ?? 1)
    }

    func updateFrequency() {
        let index = Int(frequencySlider)
        userSettings.notificationFrequency = NotificationFrequency.allCases[index]
    }

    func updateSensitivity() {
        let index = Int(sensitivitySlider)
        userSettings.notificationSensitivity = NotificationSensitivity.allCases[index]
    }

    func isPresetSelected(_ preset: MoodPreset) -> Bool {
        return userSettings.notificationFrequency == preset.frequency &&
               userSettings.notificationSensitivity == preset.sensitivity
    }
}

struct MoodPresetButton: View {
    let preset: MoodPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(preset.emoji)
                    .font(.system(size: 32))

                Text(preset.rawValue)
                    .font(WealthyRabbitTheme.captionFont)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? WealthyRabbitTheme.mossGreen.opacity(0.2) : Color.white.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? WealthyRabbitTheme.mossGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView(viewModel: RabbitViewModel())
}
