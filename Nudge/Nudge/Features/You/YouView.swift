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
import PhotosUI

struct YouView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    @Environment(AuthSession.self) private var auth

    @State private var showPaywall = false
    @State private var selectedVoice: String = NudgyConfig.Voice.openAIVoice
    @State private var isPreviewingVoice = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarService = AvatarService.shared
    @State private var showMemojiPicker = false
    @State private var showPhotoPicker = false

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

                        // Avatar / Memoji header
                        avatarHeader
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
                            VStack(spacing: DesignTokens.spacingMD) {
                                // Voice on/off toggle
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

                        // Account
                        youSection(title: String(localized: "Account")) {
                            Button {
                                auth.signOut()
                            } label: {
                                youRow(
                                    icon: "rectangle.portrait.and.arrow.right",
                                    title: String(localized: "Sign Out"),
                                    subtitle: String(localized: "Switch to a different account")
                                )
                            }
                            .buttonStyle(.plain)
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
        .sheet(isPresented: $showMemojiPicker) {
            MemojiPickerView { memojiImage in
                avatarService.setCustomAvatar(memojiImage)
            }
            .presentationDetents([.large])
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onAppear {
            avatarService.loadFromMeCard()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    avatarService.setCustomAvatar(image)
                }
                selectedPhotoItem = nil
            }
        }
    }

    // MARK: - Avatar Header
    
    private var avatarHeader: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            Menu {
                Button {
                    showMemojiPicker = true
                } label: {
                    Label(String(localized: "Choose Memoji"), systemImage: "face.smiling")
                }
                
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(String(localized: "Choose Photo"), systemImage: "photo.on.rectangle")
                }
                
                if avatarService.avatarImage != nil {
                    Divider()
                    Button(role: .destructive) {
                        avatarService.removeAvatar()
                    } label: {
                        Label(String(localized: "Remove Photo"), systemImage: "trash")
                    }
                }
            } label: {
                ZStack {
                    if let image = avatarService.avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                    } else {
                        // Initials or generic person fallback
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [DesignTokens.accentActive.opacity(0.3), DesignTokens.accentActive.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .overlay {
                                if !settings.userName.isEmpty {
                                    Text(String(settings.userName.prefix(1)).uppercased())
                                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                                        .foregroundStyle(DesignTokens.textPrimary)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(DesignTokens.textSecondary)
                                }
                            }
                    }
                    
                    // Edit badge
                    Circle()
                        .fill(DesignTokens.cardSurface)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(Color.black, lineWidth: 2)
                        }
                        .offset(x: 30, y: 30)
                }
            }
            .buttonStyle(.plain)
            .nudgeAccessibility(
                label: String(localized: "Profile photo"),
                hint: String(localized: "Tap to choose a photo or Memoji"),
                traits: .isButton
            )
            
            // Name below avatar
            if !settings.userName.isEmpty {
                Text(settings.userName)
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
            }
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
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                    .fill(isSelected ? DesignTokens.accentActive.opacity(0.12) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                            .strokeBorder(
                                isSelected ? DesignTokens.accentActive.opacity(0.4) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
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
    YouView()
        .environment(AppSettings())
        .environment(PenguinState())
}
