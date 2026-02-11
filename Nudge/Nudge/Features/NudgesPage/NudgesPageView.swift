//
//  NudgesPageView.swift
//  Nudge
//
//  The redesigned Nudges tab — "One Surface, Zero Navigation."
//
//  Layout (progressive scroll density):
//    0. Quick capture (inline, replaces toolbar + button)
//    1. Stats strip (fish, streak, snowflakes, progress)
//    2. Streak risk banner (if applicable)
//    3. Daily challenge badge (if in progress)
//    4. Hero card (THE task, picked by SmartPick)
//    5. "Not this one" skip button
//    6. Paralysis prompt (after 3 skips)
//    7. Up next (2-3 peek cards)
//    8. Done today (trophy case — glass container)
//    9. Pile count (expandable remaining)
//
//  Key innovations:
//  - Cards EXECUTE tasks, not just display them (CALL/TEXT/EMAIL buttons)
//  - SmartPick auto-chooses with energy awareness (no user decision needed)
//  - Fish bounty visible BEFORE completion (forward-looking motivation)
//  - Completion chain: card flies off → fish arc → next card rises (900ms)
//  - Paralysis detection at 3 skips → Nudgy intervention
//
//  ADHD research backing:
//  - "I know what to do, I just can't do it" (716 upvotes r/ADHD)
//  - Body doubling / "what do you need to do?" (12K upvotes)
//  - "1-thing theory" from 131 tips thread (9.6K upvotes)
//

import SwiftUI
import SwiftData
import WidgetKit

struct NudgesPageView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.selectedTab) private var selectedTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - State
    
    @State private var repository: NudgeRepository?
    
    // Data
    @State private var allActive: [NudgeItem] = []
    @State private var snoozedItems: [NudgeItem] = []
    @State private var doneToday: [NudgeItem] = []
    
    // Hero card
    @State private var heroItem: NudgeItem?
    @State private var heroReason: String = ""
    @State private var upNextItems: [NudgeItem] = []
    @State private var pileItems: [NudgeItem] = []
    
    // Skip cycle
    @State private var skipManager = SkipCycleManager()
    
    // Fish rewards
    @State private var fishHUDPosition: CGPoint = CGPoint(x: 60, y: 60)
    @State private var lastEarnedSpecies: FishSpecies?
    @State private var lastSnowflakesEarned: Int = 0
    @State private var showCompletionParticles = false
    
    // Drafting
    @State private var draftGenerationTask: Task<Void, Never>?
    
    // Message compose
    @State private var showMessageCompose = false
    @State private var messageRecipient = ""
    @State private var messageBody = ""
    
    // Focus timer
    @State private var focusTimerItem: NudgeItem?
    
    // Undo
    @State private var undoItem: NudgeItem?
    @State private var undoPreviousSortOrder: Int = 0
    @State private var showUndoToast = false
    @State private var undoTimerTask: Task<Void, Never>?
    
    // Hero card transition
    @State private var heroTransitionID = UUID()
    
    // Background glow
    @State private var breatheAnimation = false
    
    // SpeciesToast timing
    @State private var showSpeciesToast = false
    
    // Drafting indicator
    @State private var isDraftingCount: Int = 0
    
    // NudgyPeekMunch (mini penguin eating animation)
    @State private var showNudgyPeek = false
    
    // MARK: - Computed
    
    private var currentEnergy: EnergyLevel {
        let hour = Calendar.current.component(.hour, from: Date())
        return EnergyScheduler.energyBucket(for: hour)
    }
    
    private var totalToday: Int {
        allActive.count + doneToday.count
    }
    
    private var emptyVariant: NudgesEmptyState.EmptyVariant {
        if allActive.isEmpty && !doneToday.isEmpty {
            return .allClear
        }
        if allActive.isEmpty && !snoozedItems.isEmpty {
            return .allSnoozed
        }
        return .noTasks
    }
    
    // MARK: - Time-Aware Greeting
    
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return String(localized: "Good morning ☕")
        case 12..<17: return String(localized: "Good afternoon ☀️")
        case 17..<21: return String(localized: "Good evening 🌙")
        default:      return String(localized: "Late night 🌟")
        }
    }
    
    private var timeSubtitle: String {
        let active = allActive.count
        let done = doneToday.count
        if done > 0 && active > 0 {
            return String(localized: "\(done) done · \(active) to go")
        } else if active == 1 {
            return String(localized: "Just one thing today")
        } else if active > 0 {
            return String(localized: "\(active) nudges waiting")
        }
        return String(localized: "Let's get started")
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Antarctic background
                ambientBackground
                    .ignoresSafeArea()
                
                if allActive.isEmpty {
                    NudgesEmptyState(
                        variant: emptyVariant,
                        snoozedCount: snoozedItems.count,
                        lastSnowflakesEarned: lastSnowflakesEarned
                    )
                    .transition(.opacity)
                } else {
                    mainScrollContent
                        .transition(.opacity)
                }
                
                // Undo toast
                if showUndoToast {
                    undoToastOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Completion particles
                if showCompletionParticles {
                    CompletionParticles(isActive: $showCompletionParticles)
                        .allowsHitTesting(false)
                }
                
                // Fish reward flying animation
                FishRewardOverlay()
                    .allowsHitTesting(false)
                
                // Fish burst
                CompletionFishBurst()
                    .allowsHitTesting(false)
                
                // Species toast (delayed for celebration sequence)
                if showSpeciesToast, let species = lastEarnedSpecies {
                    SpeciesToast(
                        species: species,
                        snowflakesEarned: lastSnowflakesEarned,
                        isRare: species == .swordfish || species == .whale,
                        isPresented: $showSpeciesToast
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(50)
                }
                
                // NudgyPeekMunch — mini penguin eating
                if showNudgyPeek {
                    NudgyPeekMunch(isActive: $showNudgyPeek, species: lastEarnedSpecies)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(timeGreeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: DesignTokens.spacingSM) {
                        HStack(spacing: 2) {
                            SnowflakeIcon(size: 10)
                            Text("\(RewardService.shared.snowflakes)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        
                        if RewardService.shared.currentStreak > 0 {
                            HStack(spacing: 2) {
                                FlameIcon(size: 10)
                                Text("\(RewardService.shared.currentStreak)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(DesignTokens.textTertiary)
                            }
                        }
                    }
                    .opacity(0.7)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupRepository()
            refreshData()
            triggerDraftGeneration()
            syncLiveActivity()
            breatheAnimation = true
        }
        .onDisappear {
            undoTimerTask?.cancel()
            draftGenerationTask?.cancel()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .nudges {
                setupRepository()
                refreshData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            repository?.resurfaceExpiredSnoozes()
            refreshData()
            triggerDraftGeneration()
            syncLiveActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeDataChanged)) { _ in
            refreshData()
            triggerDraftGeneration()
            syncLiveActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeComposeMessage)) { notification in
            if let recipient = notification.userInfo?["recipient"] as? String,
               let body = notification.userInfo?["body"] as? String {
                messageRecipient = recipient
                messageBody = body
                if ActionService.canSendText {
                    showMessageCompose = true
                }
            }
        }
        .sheet(isPresented: $showMessageCompose) {
            if ActionService.canSendText {
                MessageComposeView(
                    recipients: [messageRecipient],
                    body: messageBody,
                    onFinished: { showMessageCompose = false }
                )
            }
        }
        .fullScreenCover(item: $focusTimerItem) { item in
            FocusTimerView(
                item: item,
                isPresented: Binding(
                    get: { focusTimerItem != nil },
                    set: { if !$0 { focusTimerItem = nil } }
                )
            )
            .onDisappear {
                refreshData()
                syncLiveActivity()
            }
        }
    }
    
    // MARK: - Main Scroll Content
    
    private var mainScrollContent: some View {
        ScrollView {
            VStack(spacing: DesignTokens.spacingLG) {
                // Time-aware subtitle + inline quick capture
                HStack(spacing: DesignTokens.spacingSM) {
                    Text(timeSubtitle)
                        .font(AppTheme.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                    
                    if isDraftingCount > 0 {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(DesignTokens.accentActive)
                            Text(String(localized: "Drafting \(isDraftingCount)..."))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.accentActive)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.spacingXS)
                
                // 1. Stats strip
                StatsStripView(
                    completedToday: doneToday.count,
                    totalToday: totalToday,
                    streak: RewardService.shared.currentStreak,
                    fishToday: RewardService.shared.tasksCompletedToday,
                    snowflakes: RewardService.shared.snowflakes,
                    lastSpecies: lastEarnedSpecies,
                    onFishHUDPosition: { pos in fishHUDPosition = pos }
                )
                .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.6)
                        .scaleEffect(phase.isIdentity ? 1 : 0.95)
                }
                
                // 2. Streak risk banner
                StreakRiskBanner(
                    streak: RewardService.shared.currentStreak,
                    completedToday: doneToday.count
                )
                
                // 3. Daily challenge badge
                ChallengeProgressBadge(
                    challenges: RewardService.shared.dailyChallenges
                )
                
                // 4. Hero card
                if let hero = heroItem {
                    HeroCardView(
                        item: hero,
                        reason: heroReason,
                        streak: RewardService.shared.currentStreak,
                        onDone: { markDoneWithCelebration(hero) },
                        onSnooze: { snoozeQuick(hero) },
                        onSkip: { skipToNext(hero) },
                        onAction: { performAction(hero) },
                        onFocus: hero.estimatedMinutes != nil
                            ? { focusTimerItem = hero }
                            : nil,
                        onRegenerate: hero.hasDraft
                            ? { regenerateDraft(hero) }
                            : nil
                    )
                    .id(heroTransitionID)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity
                        )
                    )
                    .scrollTransition(.animated(.spring(response: 0.5, dampingFraction: 0.82))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.3)
                            .scaleEffect(phase.isIdentity ? 1 : 0.92)
                            .blur(radius: phase.isIdentity ? 0 : 2)
                    }
                }
                
                // 5. "Not this one" skip button
                if heroItem != nil && allActive.count > 1 {
                    skipButton
                        .transition(.opacity)
                }
                
                // 6. Paralysis prompt
                if skipManager.showParalysisPrompt {
                    ParalysisPromptView(
                        skipCount: skipManager.skipCount,
                        onQuickCatch: {
                            if let quick = skipManager.findQuickCatch(from: allActive) {
                                promoteToHero(quick)
                            }
                            skipManager.dismissParalysisPrompt()
                        },
                        onBrainDump: {
                            skipManager.dismissParalysisPrompt()
                            NotificationCenter.default.post(name: .nudgeOpenBrainDump, object: nil)
                        },
                        onDismiss: {
                            skipManager.dismissParalysisPrompt()
                        }
                    )
                }
                
                // 7. Up next
                UpNextSection(
                    items: upNextItems,
                    streak: RewardService.shared.currentStreak,
                    onPromote: { item in promoteToHero(item) }
                )
                .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.4)
                        .offset(y: phase.isIdentity ? 0 : 20)
                }
                
                // 8. Done today
                DoneTodayStrip(items: doneToday)
                    .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.4)
                            .offset(y: phase.isIdentity ? 0 : 16)
                    }
                
                // 9. Pile
                PileCountRow(
                    items: pileItems,
                    streak: RewardService.shared.currentStreak,
                    onDone: { item in markDoneWithCelebration(item) },
                    onSnooze: { item in snoozeQuick(item) }
                )
                .scrollTransition(.animated(.spring(response: 0.4, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.4)
                        .offset(y: phase.isIdentity ? 0 : 16)
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
        .refreshable { refreshData() }
    }
    
    // MARK: - Skip Button
    
    private var skipButton: some View {
        Button {
            if let hero = heroItem {
                skipToNext(hero)
            }
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "arrow.forward.circle")
                    .font(AppTheme.footnote)
                Text(String(localized: "Not this one"))
                    .font(AppTheme.footnote.weight(.medium))
            }
            .foregroundStyle(DesignTokens.textTertiary)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingSM)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.03))
            }
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: String(localized: "Skip this task"),
            hint: String(localized: "Shows the next task Nudgy recommends"),
            traits: .isButton
        )
    }
    
    // MARK: - Ambient Background
    
    private var ambientBackground: some View {
        GeometryReader { geo in
            ZStack {
                AntarcticEnvironment(
                    mood: RewardService.shared.environmentMood,
                    unlockedProps: RewardService.shared.unlockedProps,
                    fishCount: RewardService.shared.snowflakes,
                    level: RewardService.shared.level,
                    stage: StageTier.from(level: RewardService.shared.level),
                    sceneWidth: geo.size.width,
                    sceneHeight: geo.size.height,
                    isActive: selectedTab == .nudges
                )
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignTokens.accentActive.opacity(breatheAnimation ? 0.04 : 0.01),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(y: geo.size.height * 0.3)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 5).repeatForever(autoreverses: true),
                        value: breatheAnimation
                    )
            }
        }
    }
    
    // MARK: - Undo Toast
    
    private var undoToastOverlay: some View {
        VStack {
            Spacer()
            
            HStack(spacing: DesignTokens.spacingMD) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.accentComplete)
                
                Text(String(localized: "Marked done"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Spacer()
                
                Button {
                    undoLastDone()
                } label: {
                    Text(String(localized: "Undo"))
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                }
            }
            .padding(DesignTokens.spacingLG)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 4)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, 80)
        }
    }
    
    // MARK: - Data
    
    private func setupRepository() {
        if repository == nil {
            repository = NudgeRepository(modelContext: modelContext)
        }
    }
    
    private func refreshData() {
        setupRepository()
        guard let repository else { return }
        
        let grouped = repository.fetchAllGrouped()
        
        // Apply focus filter
        let filteredActive = applyFocusFilter(grouped.active)
        
        withAnimation(AnimationConstants.springSmooth) {
            allActive = filteredActive
            snoozedItems = grouped.snoozed
            doneToday = grouped.doneToday
        }
        
        // Pick hero card
        pickHero()
    }
    
    private func applyFocusFilter(_ items: [NudgeItem]) -> [NudgeItem] {
        let defaults = UserDefaults(suiteName: AppGroupID.suiteName)
        guard let filterRaw = defaults?.string(forKey: "focusFilter_energyLevel"),
              filterRaw != "all",
              let filter = EnergyLevel(rawValue: filterRaw) else {
            return items
        }
        return items.filter { item in
            guard let energy = item.energyLevel else { return true }
            return energy == filter
        }
    }
    
    // MARK: - Hero Selection
    
    private func pickHero() {
        guard !allActive.isEmpty else {
            heroItem = nil
            heroReason = ""
            upNextItems = []
            pileItems = []
            return
        }
        
        // Exclude currently skipped items (unless all are skipped)
        let candidates = allActive.filter { !skipManager.skippedIDs.contains($0.id) }
        let pool = candidates.isEmpty ? allActive : candidates
        
        // SmartPick with energy awareness (the fix!)
        let picked = SmartPickEngine.pickBest(from: pool, currentEnergy: currentEnergy)
            ?? pool.first
        
        guard let hero = picked else { return }
        
        // Only change hero if it's different (avoid re-picks on refresh)
        if heroItem?.id != hero.id {
            withAnimation(reduceMotion ? .none : AnimationConstants.springSmooth) {
                heroItem = hero
                heroReason = SmartPickEngine.reason(for: hero)
                heroTransitionID = UUID() // Force new transition
            }
            
            // Trigger draft generation for new hero
            triggerHeroDraft(hero)
        }
        
        // Build up-next and pile lists
        let remaining = allActive.filter { $0.id != hero.id }
        withAnimation(AnimationConstants.springSmooth) {
            upNextItems = Array(remaining.prefix(3))
            pileItems = remaining.count > 3 ? Array(remaining.dropFirst(3)) : []
        }
    }
    
    // MARK: - Actions
    
    private func markDoneWithCelebration(_ item: NudgeItem) {
        let previousSortOrder = item.sortOrder
        repository?.markDone(item)
        HapticService.shared.swipeDone()
        SoundService.shared.playTaskDone()
        
        // Remove from Spotlight
        SpotlightIndexer.removeTask(id: item.id)
        
        // Phase 7: Celebration particles
        showCompletionParticles = true
        
        // Record fish reward
        let isAllClear = allActive.count <= 1
        let earned = RewardService.shared.recordCompletion(
            context: modelContext,
            item: item,
            isAllClear: isAllClear
        )
        let species = FishEconomy.speciesForTask(item)
        lastEarnedSpecies = species
        lastSnowflakesEarned = earned
        
        // Post fish burst
        NotificationCenter.default.post(
            name: .nudgeFishBurst,
            object: nil,
            userInfo: [
                "origin": CGPoint(x: 200, y: 400),
                "hudPosition": fishHUDPosition,
                "fishCount": min(species.snowflakeValue, 5)
            ]
        )
        SoundService.shared.playFishCaught()
        
        // Pending fish for penguin tab
        NotificationCenter.default.post(
            name: .nudgePendingFish,
            object: nil,
            userInfo: ["count": 1]
        )
        
        // Tab chomp → NudgyPeek → SpeciesToast (sequenced)
        Task { @MainActor in
            // 0.4s — tab chomp
            try? await Task.sleep(for: .seconds(0.4))
            NotificationCenter.default.post(
                name: .nudgeTabChomp,
                object: nil,
                userInfo: ["species": species.label]
            )
            
            // 0.8s — NudgyPeekMunch
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(AnimationConstants.springSmooth) {
                showNudgyPeek = true
            }
            
            // 1.2s — SpeciesToast slides in
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showSpeciesToast = true
            }
            
            // 4.2s — auto-dismiss SpeciesToast
            try? await Task.sleep(for: .seconds(3.0))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showSpeciesToast = false
            }
            // Clear species after animation
            try? await Task.sleep(for: .seconds(0.35))
            lastEarnedSpecies = nil
            lastSnowflakesEarned = 0
        }
        
        // Reset skip cycle
        skipManager.recordCompletion()
        
        // Undo
        undoItem = item
        undoPreviousSortOrder = previousSortOrder
        undoTimerTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showUndoToast = true
        }
        undoTimerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            dismissUndoToast()
        }
        
        // Refresh and sync
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }
    
    private func snoozeQuick(_ item: NudgeItem) {
        let snoozeDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        repository?.snooze(item, until: snoozeDate)
        HapticService.shared.swipeSnooze()
        SoundService.shared.playSnooze()
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }
    
    private func skipToNext(_ item: NudgeItem) {
        HapticService.shared.prepare()
        
        withAnimation(reduceMotion ? .none : AnimationConstants.springSmooth) {
            skipManager.recordSkip(item: item, streak: RewardService.shared.currentStreak)
            pickHero()
        }
    }
    
    private func promoteToHero(_ item: NudgeItem) {
        HapticService.shared.actionButtonTap()
        
        // Reset skips when user makes a deliberate choice
        skipManager.recordCompletion()
        
        withAnimation(reduceMotion ? .none : AnimationConstants.springSmooth) {
            heroItem = item
            heroReason = SmartPickEngine.reason(for: item)
            heroTransitionID = UUID()
            
            let remaining = allActive.filter { $0.id != item.id }
            upNextItems = Array(remaining.prefix(3))
            pileItems = remaining.count > 3 ? Array(remaining.dropFirst(3)) : []
        }
        
        triggerHeroDraft(item)
    }
    
    private func performAction(_ item: NudgeItem) {
        guard let actionType = item.actionType else { return }
        HapticService.shared.actionButtonTap()
        ActionService.perform(action: actionType, item: item)
    }
    
    private func undoLastDone() {
        guard let item = undoItem else { return }
        repository?.undoDone(item, restoreSortOrder: undoPreviousSortOrder)
        undoTimerTask?.cancel()
        dismissUndoToast()
        HapticService.shared.prepare()
        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
    }
    
    private func dismissUndoToast() {
        withAnimation(AnimationConstants.springSmooth) {
            showUndoToast = false
        }
        undoItem = nil
    }
    
    // MARK: - Draft Generation
    
    private func triggerDraftGeneration() {
        guard let repository else { return }
        draftGenerationTask?.cancel()
        draftGenerationTask = Task {
            let needsDraft = allActive.filter { item in
                guard let actionType = item.actionType,
                      actionType == .text || actionType == .email else { return false }
                return !item.hasDraft
            }
            
            for item in needsDraft {
                guard !Task.isCancelled else { break }
                await DraftService.shared.generateDraftIfNeeded(
                    for: item,
                    isPro: settings.isPro,
                    repository: repository,
                    senderName: settings.userName.isEmpty ? nil : settings.userName
                )
            }
        }
    }
    
    private func triggerHeroDraft(_ item: NudgeItem) {
        guard let repository,
              let actionType = item.actionType,
              actionType == .text || actionType == .email,
              !item.hasDraft else { return }
        
        Task {
            await DraftService.shared.generateDraftIfNeeded(
                for: item,
                isPro: settings.isPro,
                repository: repository,
                senderName: settings.userName.isEmpty ? nil : settings.userName
            )
            // Refresh to show the newly generated draft
            refreshData()
        }
    }
    
    private func regenerateDraft(_ item: NudgeItem) {
        guard let repository else { return }
        Task {
            await DraftService.shared.regenerateDraft(
                for: item,
                isPro: settings.isPro,
                repository: repository,
                senderName: settings.userName.isEmpty ? nil : settings.userName
            )
            refreshData()
        }
    }
    
    // MARK: - Live Activity
    
    private func syncLiveActivity() {
        syncWidgetData()
        
        if let repository {
            SpotlightIndexer.indexAllTasks(from: repository)
        }
        
        guard settings.liveActivityEnabled else { return }
        
        guard let topItem = heroItem ?? allActive.first else {
            Task { await LiveActivityManager.shared.endIfEmpty() }
            return
        }
        
        let emoji = topItem.emoji ?? "pin.fill"
        let accentHex: String
        switch topItem.accentStatus {
        case .stale:    accentHex = "FFB800"
        case .overdue:  accentHex = "FF453A"
        case .complete: accentHex = "30D158"
        case .active:   accentHex = "0A84FF"
        }
        
        if LiveActivityManager.shared.isRunning {
            Task {
                await LiveActivityManager.shared.update(
                    taskContent: topItem.content,
                    taskEmoji: emoji,
                    queuePosition: 1,
                    queueTotal: allActive.count,
                    accentHex: accentHex,
                    taskID: topItem.id.uuidString
                )
            }
        } else {
            LiveActivityManager.shared.start(
                taskContent: topItem.content,
                taskEmoji: emoji,
                queuePosition: 1,
                queueTotal: allActive.count,
                accentHex: accentHex,
                taskID: topItem.id.uuidString
            )
        }
    }
    
    private func syncWidgetData() {
        guard let defaults = UserDefaults(suiteName: AppGroupID.suiteName) else { return }
        
        let nextItem = heroItem ?? allActive.first
        defaults.set(nextItem?.content, forKey: "widget_nextTask")
        defaults.set(nextItem?.emoji ?? "🐧", forKey: "widget_nextTaskEmoji")
        defaults.set(nextItem?.id.uuidString, forKey: "widget_nextTaskID")
        defaults.set(allActive.count, forKey: "widget_activeCount")
        defaults.set(doneToday.count, forKey: "widget_completedToday")
        defaults.set(totalToday, forKey: "widget_totalToday")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NudgeItem.self, BrainDump.self, NudgyWardrobe.self, configurations: config)
    
    let ctx = container.mainContext
    let item1 = NudgeItem(content: "Call Dr. Patel about prescription", emoji: "📞", actionType: .call, actionTarget: "555-1234", contactName: "Dr. Patel", sortOrder: 1)
    item1.aiDraft = "Ask about prescription renewal\nConfirm next appointment"
    item1.estimatedMinutes = 10
    ctx.insert(item1)
    
    let item2 = NudgeItem(content: "Text Sarah about Saturday plans", emoji: "💬", actionType: .text, actionTarget: "555-5678", contactName: "Sarah", sortOrder: 2)
    item2.aiDraft = "Hey Sarah! Are we still on for brunch at 11?"
    ctx.insert(item2)
    
    ctx.insert(NudgeItem(content: "Buy dog food", emoji: "🐶", sortOrder: 3))
    ctx.insert(NudgeItem(content: "Clean kitchen", emoji: "🧹", sortOrder: 4))
    ctx.insert(NudgeItem(content: "File expense report", emoji: "📊", sortOrder: 5))
    
    return NudgesPageView()
        .modelContainer(container)
        .environment(AppSettings())
        .environment(PenguinState())
}
