//
//  YouSettingsView.swift
//  Nudge
//
//  All configuration settings extracted from YouView.
//  Presented as a sheet from the gear icon on the You tab.
//
//  Sections: About You, Nudge Style, Routines, Import,
//  Lock Screen, Nudgy, Your Style, Upgrade, About, Account.
//

import SwiftUI
import StoreKit
import TipKit

struct YouSettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var selectedVoice: String = NudgyConfig.Voice.openAIVoice
    @State private var isPreviewingVoice = false
    @State private var showPersonaPicker = false
    @State private var showRemindersImport = false

    private let liveActivityTip = LiveActivityTip()

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ZStack {
                // Background
                ZStack {
                    Color.black.ignoresSafeArea()
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DesignTokens.accentActive.opacity(0.04), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                        .offset(x: 80, y: -100)
                        .blur(radius: 60)
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignTokens.spacingLG) {

                        // MARK: About You

                        settingsSection(title: String(localized: "About You")) {
                            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                                settingsRow(
                                    icon: "person.fill",
                                    title: String(localized: "Your Name"),
                                    subtitle: String(localized: "Nudgy uses this to personalize conversations and sign off drafted messages")
                                )

                                TextField(
                                    String(localized: "First name"),
                                    text: $settings.userName
                                )
                                .font(AppTheme.body)
                                .foregroundStyle(DesignTokens.textPrimary)
                                .padding(DesignTokens.spacingMD)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                        }

                        // MARK: Nudge Style

                        settingsSection(title: String(localized: "Nudge Style")) {
                            VStack(spacing: DesignTokens.spacingMD) {
                                settingsRow(
                                    icon: "moon.fill",
                                    title: String(localized: "Quiet Hours Start"),
                                    value: "\(formatHour(settings.quietHoursStart))"
                                )

                                Picker(String(localized: "Start"), selection: $settings.quietHoursStart) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(formatHour(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 100)

                                settingsRow(
                                    icon: "sunrise.fill",
                                    title: String(localized: "Quiet Hours End"),
                                    value: "\(formatHour(settings.quietHoursEnd))"
                                )

                                Picker(String(localized: "End"), selection: $settings.quietHoursEnd) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(formatHour(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 100)

                                Stepper(
                                    value: $settings.maxDailyNudges,
                                    in: 1...10
                                ) {
                                    settingsRow(
                                        icon: "bell.fill",
                                        title: String(localized: "Max Daily Nudges"),
                                        value: "\(settings.maxDailyNudges)"
                                    )
                                }
                            }
                        }

                        // MARK: Routines

                        settingsSection(title: String(localized: "Routines")) {
                            NavigationLink {
                                RoutineListView()
                            } label: {
                                settingsRow(
                                    icon: "arrow.trianglehead.2.counterclockwise.circle.fill",
                                    title: String(localized: "My Routines"),
                                    subtitle: String(localized: "Auto-generate daily tasks from repeating habits")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // MARK: Import

                        settingsSection(title: String(localized: "Import")) {
                            Button {
                                showRemindersImport = true
                            } label: {
                                settingsRow(
                                    icon: "checklist",
                                    title: String(localized: "Import from Reminders"),
                                    subtitle: String(localized: "Bring in tasks from Apple Reminders")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // MARK: Lock Screen

                        settingsSection(title: String(localized: "Lock Screen")) {
                            VStack(spacing: DesignTokens.spacingSM) {
                                TipView(liveActivityTip)
                                    .tipBackground(DesignTokens.cardSurface)

                                Toggle(isOn: $settings.liveActivityEnabled) {
                                    settingsRow(
                                        icon: "lock.circle.fill",
                                        title: String(localized: "Show on Lock Screen"),
                                        subtitle: String(localized: "Current task on Dynamic Island & Lock Screen")
                                    )
                                }
                                .tint(DesignTokens.accentActive)
                                .onChange(of: settings.liveActivityEnabled) { _, newValue in
                                    if newValue {
                                        Task { await LiveActivityTip.liveActivityEnabled.donate() }
                                    }
                                }
                            }
                        }

                        // MARK: Nudgy

                        settingsSection(title: String(localized: "Nudgy")) {
                            VStack(spacing: DesignTokens.spacingMD) {
                                // Nudgy's Memory
                                NavigationLink {
                                    NudgyMemoryView()
                                } label: {
                                    settingsRow(
                                        icon: "brain.head.profile.fill",
                                        title: String(localized: "Nudgy's Memory"),
                                        subtitle: String(localized: "See what Nudgy remembers about you")
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .overlay(Color.white.opacity(0.06))

                                // Voice on/off toggle
                                Toggle(isOn: Binding(
                                    get: { NudgyVoiceOutput.shared.isEnabled },
                                    set: { NudgyVoiceOutput.shared.isEnabled = $0 }
                                )) {
                                    settingsRow(
                                        icon: "waveform.circle.fill",
                                        title: String(localized: "Nudgy's Voice"),
                                        subtitle: String(localized: "Nudgy reads responses aloud")
                                    )
                                }
                                .tint(DesignTokens.accentActive)

                                // Voice picker (only when voice is on)
                                if NudgyVoiceOutput.shared.isEnabled {
                                    Divider()
                                        .overlay(Color.white.opacity(0.06))

                                    VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                                        Text(String(localized: "Voice"))
                                            .font(AppTheme.caption.weight(.semibold))
                                            .foregroundStyle(DesignTokens.textSecondary)

                                        // Voice options grid
                                        LazyVGrid(columns: [
                                            GridItem(.flexible()),
                                            GridItem(.flexible()),
                                            GridItem(.flexible())
                                        ], spacing: DesignTokens.spacingSM) {
                                            ForEach(NudgyConfig.Voice.availableVoices, id: \.id) { voice in
                                                voiceButton(voice: voice)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // MARK: Your Style

                        settingsSection(title: String(localized: "Your Style")) {
                            VStack(spacing: DesignTokens.spacingSM) {
                                Button {
                                    showPersonaPicker = true
                                } label: {
                                    HStack(spacing: DesignTokens.spacingMD) {
                                        Image(systemName: settings.selectedPersona.icon)
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color(hex: settings.selectedPersona.accentColorHex))
                                            .frame(width: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(settings.selectedPersona.label)
                                                .font(AppTheme.body)
                                                .foregroundStyle(DesignTokens.textPrimary)
                                            Text(String(localized: "Tap to change how Nudgy adapts"))
                                                .font(AppTheme.footnote)
                                                .foregroundStyle(DesignTokens.textSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(DesignTokens.textTertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // MARK: Upgrade

                        if !settings.isPro {
                            settingsSection(title: String(localized: "Upgrade")) {
                                Button {
                                    showPaywall = true
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                                            Text(String(localized: "Nudge Pro"))
                                                .font(AppTheme.body.weight(.semibold))
                                                .foregroundStyle(DesignTokens.textPrimary)
                                            Text(String(localized: "Unlimited brain unloads, AI drafts, and more"))
                                                .font(AppTheme.caption)
                                                .foregroundStyle(DesignTokens.textSecondary)
                                        }
                                        Spacer()
                                        Text(PurchaseService.shared.monthlyProduct?.displayPrice ?? String(localized: "Upgrade"))
                                            .font(AppTheme.body.weight(.bold))
                                            .foregroundStyle(DesignTokens.accentActive)
                                    }
                                    .padding(DesignTokens.spacingMD)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                            .fill(DesignTokens.accentActive.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                                    .strokeBorder(DesignTokens.accentActive.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // MARK: About

                        settingsSection(title: String(localized: "About")) {
                            VStack(spacing: DesignTokens.spacingSM) {
                                settingsRow(
                                    icon: "info.circle.fill",
                                    title: String(localized: "Version"),
                                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                                )

                                Button {
                                    if let url = URL(string: "mailto:support@nudgeapp.com") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    settingsRow(
                                        icon: "envelope.fill",
                                        title: String(localized: "Contact Support")
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // MARK: Account

                        settingsSection(title: String(localized: "Account")) {
                            Button {
                                auth.signOut()
                            } label: {
                                settingsRow(
                                    icon: "rectangle.portrait.and.arrow.right",
                                    title: String(localized: "Sign Out"),
                                    subtitle: String(localized: "Switch to a different account")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Bottom padding
                        Spacer(minLength: DesignTokens.spacingXXXL)
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }
            .navigationTitle(String(localized: "Settings"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    .nudgeAccessibility(
                        label: String(localized: "Close settings"),
                        hint: String(localized: "Returns to the You page"),
                        traits: .isButton
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showPersonaPicker) {
            PersonaPickerView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showRemindersImport) {
            RemindersImportView()
                .presentationDetents([.large])
        }
    }

    // MARK: - Reusable Components

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(title)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)

            content()
                .padding(DesignTokens.spacingMD)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }

    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        value: String? = nil
    ) -> some View {
        HStack(spacing: DesignTokens.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DesignTokens.accentActive)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }

            Spacer()

            if let value {
                Text(value)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return formatter.string(from: date)
    }

    // MARK: - Voice Button

    private func voiceButton(voice: (id: String, name: String, description: String)) -> some View {
        let isSelected = selectedVoice == voice.id

        return Button {
            selectedVoice = voice.id
            NudgyConfig.Voice.openAIVoice = voice.id

            // Preview the voice
            isPreviewingVoice = true
            NudgyVoiceOutput.shared.speakReaction("Hey! I'm Nudgy!")

            Task {
                try? await Task.sleep(for: .seconds(3))
                isPreviewingVoice = false
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? DesignTokens.accentActive : DesignTokens.textTertiary)

                Text(voice.name)
                    .font(AppTheme.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? DesignTokens.textPrimary : DesignTokens.textSecondary)

                Text(voice.description)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingSM)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                        .fill(DesignTokens.accentActive.opacity(0.12))
                }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusButton))
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: "\(voice.name) voice, \(voice.description)",
            hint: isSelected
                ? String(localized: "Currently selected")
                : String(localized: "Double tap to select and preview")
        )
    }
}

// MARK: - Preview

#Preview {
    YouSettingsView()
        .environment(AppSettings())
        .environment(PenguinState())
        .environment(AuthSession())
}
