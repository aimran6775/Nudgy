//
//  YouView.swift
//  Nudge
//
//  The "You" tab — your experience page.
//  Hero: aquarium tank with vector fish (Phase 2).
//  Quick mood check-in + AI insights (Phase 3-4).
//  Settings extracted to YouSettingsView (gear icon).
//

import SwiftUI
import PhotosUI
import SwiftData

struct YouView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    @Environment(AuthSession.self) private var auth
    @Environment(\.modelContext) private var modelContext

    // Avatar
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarService = AvatarService.shared
    @State private var showMemojiPicker = false
    @State private var showPhotoPicker = false

    // Sheets
    @State private var showSettings = false
    @State private var showDailyReview = false
    @State private var showFullCheckIn = false
    @State private var showFullAquarium = false

    // Mood (quick check-in)
    @State private var todayMood: MoodLevel?
    @State private var moodSaved = false

    // Reward service for aquarium data
    @State private var rewardService = RewardService.shared

    // AI insight
    @State private var moodInsightText: String?
    @State private var isLoadingInsight = false

    // Mood entries for insight generation
    @Query(sort: \MoodEntry.loggedAt, order: .reverse) private var recentMoodEntries: [MoodEntry]

    var body: some View {
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

                        // MARK: Aquarium Hero

                        youSectionRaw(title: String(localized: "Your Aquarium")) {
                            VStack(spacing: 0) {
                                AquariumTankView(
                                    catches: rewardService.fishCatches,
                                    level: rewardService.level,
                                    streak: rewardService.currentStreak,
                                    height: 200
                                )
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: DesignTokens.cornerRadiusCard - 4,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: DesignTokens.cornerRadiusCard - 4
                                    )
                                )

                                // Weekly progress bar
                                aquariumProgressBar

                                // See full aquarium link
                                NavigationLink {
                                    AquariumView(
                                        catches: rewardService.fishCatches,
                                        level: rewardService.level,
                                        streak: rewardService.currentStreak
                                    )
                                } label: {
                                    HStack {
                                        Text(String(localized: "See Full Aquarium"))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(DesignTokens.accentActive)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(DesignTokens.accentActive.opacity(0.6))
                                    }
                                    .padding(.horizontal, DesignTokens.spacingMD)
                                    .padding(.vertical, DesignTokens.spacingSM + 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // MARK: Quick Mood Check-In

                        youSection(title: String(localized: "How are you feeling?")) {
                            quickMoodRow
                        }

                        // MARK: AI Mood Insight

                        if !recentMoodEntries.isEmpty {
                            moodInsightCard
                        }

                        // MARK: Mood History

                        youSection(title: String(localized: "Mood")) {
                            VStack(spacing: DesignTokens.spacingSM) {
                                NavigationLink {
                                    MoodCheckInView()
                                } label: {
                                    youRow(
                                        icon: "face.smiling.inverse",
                                        title: String(localized: "Full Check-In"),
                                        subtitle: String(localized: "Log mood, energy & notes")
                                    )
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    MoodInsightsView()
                                } label: {
                                    youRow(
                                        icon: "chart.line.uptrend.xyaxis",
                                        title: String(localized: "Mood Insights"),
                                        subtitle: String(localized: "See trends and productivity patterns")
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // MARK: Daily Review

                        youSection(title: String(localized: "Daily Review")) {
                            Button {
                                showDailyReview = true
                            } label: {
                                youRow(
                                    icon: "moon.stars.fill",
                                    title: String(localized: "Review My Day"),
                                    subtitle: String(localized: "See what you accomplished and plan tomorrow")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // MARK: Upgrade (subtle banner if not Pro)

                        if !settings.isPro {
                            youSection(title: String(localized: "Upgrade")) {
                                Button {
                                    showSettings = true
                                } label: {
                                    HStack(spacing: DesignTokens.spacingMD) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.yellow)
                                            .frame(width: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(String(localized: "Nudge Pro"))
                                                .font(AppTheme.body.weight(.semibold))
                                                .foregroundStyle(DesignTokens.textPrimary)
                                            Text(String(localized: "Unlock unlimited brain unloads & more"))
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

                        // Bottom padding
                        Spacer(minLength: DesignTokens.spacingXXXL)
                    }
                    .padding(.horizontal, DesignTokens.spacingLG)
                }
            }
            .navigationTitle(String(localized: "You"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    .nudgeAccessibility(
                        label: String(localized: "Settings"),
                        hint: String(localized: "Open app settings"),
                        traits: .isButton
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            YouSettingsView()
        }
        .sheet(isPresented: $showMemojiPicker) {
            MemojiPickerView { memojiImage in
                avatarService.setCustomAvatar(memojiImage)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showDailyReview) {
            DailyReviewView()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onAppear {
            avatarService.loadFromMeCard()
            loadTodayMood()
            loadMoodInsight()
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

    // MARK: - Aquarium Progress Bar

    private var aquariumProgressBar: some View {
        let weekCatches = weeklyFishCount
        let cap = 12
        let progress = min(Double(weekCatches) / Double(cap), 1.0)

        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "4FC3F7"),
                                    Color(hex: "00B8D4")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(String(localized: "\(weekCatches) fish this week"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignTokens.textTertiary)
                Spacer()
                Text(String(localized: "Lv.\(rewardService.level)"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "FFD54F"))
            }
        }
        .padding(.horizontal, DesignTokens.spacingMD)
        .padding(.vertical, DesignTokens.spacingSM)
    }

    private var weeklyFishCount: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return rewardService.fishCatches.count
        }
        return rewardService.fishCatches.filter { $0.caughtAt >= weekStart }.count
    }

    // MARK: - Quick Mood Row

    private var quickMoodRow: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            if moodSaved, let mood = todayMood {
                // Already checked in today — show summary
                HStack(spacing: DesignTokens.spacingMD) {
                    Text(mood.emoji)
                        .font(.system(size: 32))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Today's mood: \(mood.label)"))
                            .font(AppTheme.body.weight(.medium))
                            .foregroundStyle(DesignTokens.textPrimary)
                        Text(String(localized: "Tap an emoji to update"))
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(mood.color)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Emoji row — always visible for 1-tap re-log
            HStack(spacing: 0) {
                ForEach(MoodLevel.allCases, id: \.self) { mood in
                    Button {
                        quickLogMood(mood)
                    } label: {
                        VStack(spacing: 3) {
                            Text(mood.emoji)
                                .font(.system(size: 28))
                                .scaleEffect(todayMood == mood ? 1.15 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: todayMood)

                            Text(mood.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(
                                    todayMood == mood
                                        ? mood.color
                                        : DesignTokens.textTertiary
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    todayMood == mood
                                        ? mood.color.opacity(0.12)
                                        : Color.clear
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .nudgeAccessibility(
                        label: mood.label,
                        hint: String(localized: "Quick log \(mood.label) mood"),
                        traits: .isButton
                    )
                }
            }
        }
    }

    // MARK: - AI Mood Insight Card

    private var moodInsightCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(String(localized: "Mood Insight"))
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "BA68C8"), Color(hex: "7B1FA2")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(String(localized: "AI-Powered"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignTokens.textTertiary)

                    Spacer()

                    if isLoadingInsight {
                        ProgressView()
                            .tint(DesignTokens.textTertiary)
                            .scaleEffect(0.7)
                    }
                }

                if isLoadingInsight {
                    // Shimmer placeholder
                    insightShimmer
                } else if let insight = moodInsightText {
                    Text(insight)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                } else {
                    Text(String(localized: "Check in a few more times to unlock AI mood insights."))
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .padding(DesignTokens.spacingMD)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }

    private var insightShimmer: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                ShimmerRect(maxWidth: i == 2 ? 140.0 : nil)
            }
        }
    }

    // MARK: - Mood Helpers

    private func loadTodayMood() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        if let todayEntry = recentMoodEntries.first(where: { calendar.isDate($0.loggedAt, inSameDayAs: todayStart) }) {
            todayMood = todayEntry.moodLevel
            moodSaved = true
        }
    }

    private func quickLogMood(_ mood: MoodLevel) {
        HapticService.shared.actionButtonTap()

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        // Check if there's already a mood entry for today — update it
        if let existing = recentMoodEntries.first(where: { calendar.isDate($0.loggedAt, inSameDayAs: todayStart) }) {
            existing.moodLevel = mood
            existing.loggedAt = Date()
        } else {
            // Create new
            let entry = MoodEntry(mood: mood)
            modelContext.insert(entry)
        }

        withAnimation(AnimationConstants.springSmooth) {
            todayMood = mood
            moodSaved = true
        }

        // Refresh insight after mood change
        loadMoodInsight()
    }

    // MARK: - AI Insight

    private func loadMoodInsight() {
        // Need at least 3 entries for meaningful insight
        guard recentMoodEntries.count >= 3 else { return }

        // Check cache — only refresh once per day
        let cacheKey = "moodInsight_\(formattedToday)"
        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            moodInsightText = cached
            return
        }

        isLoadingInsight = true

        Task {
            let prompt = buildInsightPrompt()
            let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt)

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoadingInsight = false
                    moodInsightText = response
                }

                // Cache for the day
                if let response {
                    UserDefaults.standard.set(response, forKey: cacheKey)
                }
            }
        }
    }

    private func buildInsightPrompt() -> String {
        let recent = Array(recentMoodEntries.prefix(7))
        let entries = recent.map { entry in
            let mood = entry.moodLevel
            let day = entry.loggedAt.formatted(.dateTime.weekday(.wide))
            let tasks = entry.tasksCompletedThatDay
            return "\(day): \(mood.label) (\(mood.emoji)), \(tasks) tasks done"
        }.joined(separator: "\n")

        return """
        You are Nudgy, a warm supportive ADHD productivity companion (a penguin!). \
        Analyze this user's recent mood entries and give a brief, encouraging 1-2 sentence insight. \
        Be specific to the data. Don't use bullet points. Keep it conversational and kind.

        Recent mood data:
        \(entries)

        Respond with just the insight text, nothing else.
        """
    }

    private var formattedToday: String {
        Date().formatted(.dateTime.year().month().day())
    }

    // MARK: - Reusable Components

    func youSection(title: String, @ViewBuilder content: () -> some View) -> some View {
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

    /// Section variant without inner padding — for edge-to-edge content like the aquarium tank.
    func youSectionRaw(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(title)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)

            content()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
        }
    }

    func youRow(
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
}

// MARK: - Shimmer Loading Rect

/// A simple pulsing placeholder rect for loading states.
private struct ShimmerRect: View {
    var maxWidth: CGFloat?

    @State private var phase: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(phase ? 0.08 : 0.03))
            .frame(height: 12)
            .frame(maxWidth: maxWidth ?? .infinity)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: phase
            )
            .onAppear { phase = true }
    }
}

// MARK: - Preview

#Preview {
    YouView()
        .environment(AppSettings())
        .environment(PenguinState())
        .environment(AuthSession())
}
