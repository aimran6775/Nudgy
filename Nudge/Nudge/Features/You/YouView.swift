//
//  YouView.swift
//  Nudge
//
//  The "You" tab — personalization.
//  This is how you make Nudgy yours: your name, preferences,
//  notification style, and Pro upgrade.
//
//  Reframed from "Settings" to "You" — it's about personalizing
//  Nudgy to work the way your brain works.
//

import SwiftUI
import StoreKit
import TipKit

struct YouView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState

    @State private var showPaywall = false

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

                        // Your penguin
                        PenguinSceneView(
                            size: .medium,
                            expressionOverride: .idle,
                            accentColorOverride: DesignTokens.accentActive
                        )
                        .padding(.top, DesignTokens.spacingLG)

                        // Your Name — how Nudgy addresses you
                        youSection(title: String(localized: "About You")) {
                            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                                youRow(
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

                        // Nudge Style — how often Nudgy checks in
                        youSection(title: String(localized: "Nudge Style")) {
                            VStack(spacing: DesignTokens.spacingMD) {
                                youRow(
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

                                youRow(
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
                                    youRow(
                                        icon: "bell.fill",
                                        title: String(localized: "Max Daily Nudges"),
                                        value: "\(settings.maxDailyNudges)"
                                    )
                                }
                            }
                        }

                        // Lock Screen
                        youSection(title: String(localized: "Lock Screen")) {
                            VStack(spacing: DesignTokens.spacingSM) {
                                TipView(liveActivityTip)
                                    .tipBackground(DesignTokens.cardSurface)

                                Toggle(isOn: $settings.liveActivityEnabled) {
                                    youRow(
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

                        youSection(title: String(localized: "Nudgy")) {
                            Toggle(isOn: Binding(
                                get: { NudgyVoiceOutput.shared.isEnabled },
                                set: { NudgyVoiceOutput.shared.isEnabled = $0 }
                            )) {
                                youRow(
                                    icon: "waveform.circle.fill",
                                    title: String(localized: "Nudgy's Voice"),
                                    subtitle: String(localized: "Nudgy reads responses aloud")
                                )
                            }
                            .tint(DesignTokens.accentActive)
                        }

                        // Pro
                        if !settings.isPro {
                            youSection(title: String(localized: "Upgrade")) {
                                Button {
                                    showPaywall = true
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                                            Text(String(localized: "Nudge Pro"))
                                                .font(AppTheme.body.weight(.semibold))
                                                .foregroundStyle(DesignTokens.textPrimary)
                                            Text(String(localized: "Unlimited brain dumps, AI drafts, and more"))
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

                        // About
                        youSection(title: String(localized: "About")) {
                            VStack(spacing: DesignTokens.spacingSM) {
                                youRow(
                                    icon: "info.circle.fill",
                                    title: String(localized: "Version"),
                                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                                )

                                Button {
                                    if let url = URL(string: "mailto:support@nudgeapp.com") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    youRow(
                                        icon: "envelope.fill",
                                        title: String(localized: "Contact Support")
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Spacer for bottom padding
                        Spacer(minLength: DesignTokens.spacingXXXL)
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }
            .navigationTitle(String(localized: "You"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Reusable Components

    private func youSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(title)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)

            content()
                .padding(DesignTokens.spacingMD)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .fill(Color.white.opacity(0.03))
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    }
                }
        }
    }

    private func youRow(
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
}

// MARK: - Preview

#Preview {
    YouView()
        .environment(AppSettings())
        .environment(PenguinState())
}
