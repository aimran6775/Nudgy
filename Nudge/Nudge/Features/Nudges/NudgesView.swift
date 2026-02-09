//
//  NudgesView.swift
//  Nudge
//
//  The "Nudges" tab — time-horizon grouped task view.
//
//  ADHD-optimized layout (Phase 1):
//  • Day-grouped collapsible sections: Today → Tomorrow → This Week → Later → Snoozed → Done
//  • Daily progress header with animated ring
//  • "Today" capped at 5 items (working memory limit, Rapport et al., 2008)
//  • Swipe-to-complete and swipe-to-snooze gestures
//  • Items with drafts/actions surface at the top of their group
//

import SwiftUI
import SwiftData
import os.log

private let nudgesLog = Logger(subsystem: "com.tarsitgroup.nudge", category: "NudgesView")

struct NudgesView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(PenguinState.self) private var penguinState
    @Environment(AppSettings.self) private var settings

    @State private var repository: NudgeRepository?

    // Time-horizon grouped items
    @State private var horizonGroups = TimeHorizonGroups()
    
    // Section expand/collapse state (persisted per session)
    @State private var expandedSections: Set<TimeHorizon> = [.today, .tomorrow]
    
    // Draft generation
    @State private var draftGenerationTask: Task<Void, Never>?
    @State private var isDraftingCount: Int = 0
    
    // AI insight
    @State private var aiInsight: String?
    @State private var isGeneratingInsight = false

    // Editing
    @State private var editingItem: NudgeItem?
    @State private var showSnoozeFor: NudgeItem?
    @State private var showBreakdownFor: NudgeItem?
    @State private var showDraftFor: NudgeItem?

    // Message compose
    @State private var showMessageCompose = false
    @State private var messageRecipient = ""
    @State private var messageBody = ""

    // Undo
    @State private var undoItem: NudgeItem?
    @State private var undoPreviousSortOrder: Int = 0
    @State private var showUndoToast = false
    @State private var undoTimerTask: Task<Void, Never>?
    
    // Live Activity prompt
    @State private var showLiveActivityPrompt = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if horizonGroups.isEmpty {
                    emptyView
                } else {
                    listContent
                }

                // Undo toast
                if showUndoToast {
                    undoToastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(String(localized: "Nudges"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignTokens.accentActive)
                    }
                    .nudgeAccessibility(
                        label: String(localized: "Add task"),
                        hint: String(localized: "Opens quick add"),
                        traits: .isButton
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupRepository()
            refreshData()
            triggerDraftGeneration()
            generateAIInsight()
            syncLiveActivity()
            promptLiveActivityIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            repository?.resurfaceExpiredSnoozes()
            refreshData()
            triggerDraftGeneration()
            generateAIInsight()
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
        .sheet(item: $editingItem) { item in
            ItemEditSheet(item: item) {
                refreshData()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $showSnoozeFor) { item in
            SnoozePickerView(item: item) { date in
                repository?.snooze(item, until: date)
                showSnoozeFor = nil
                refreshData()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $showBreakdownFor) { item in
            TaskBreakdownView(
                taskContent: item.content,
                taskEmoji: item.emoji
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.black)
        }
        .sheet(item: $showDraftFor) { item in
            DraftPreviewSheet(item: item) {
                ActionService.perform(action: item.actionType ?? .text, item: item)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
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
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingLG) {
                
                // Daily progress header
                DailyProgressHeader(
                    completedToday: horizonGroups.doneToday.count,
                    totalToday: horizonGroups.today.count + horizonGroups.doneToday.count,
                    streak: RewardService.shared.currentStreak
                )
                
                // Live Activity opt-in prompt
                if showLiveActivityPrompt && !settings.liveActivityEnabled {
                    liveActivityPromptBanner
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // AI Insight banner — contextual advice from Nudgy
                if let insight = aiInsight, !insight.isEmpty {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image("NudgyMascot")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Text(insight)
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(3)
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.easeOut(duration: 0.25)) {
                                aiInsight = nil
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(DesignTokens.spacingMD)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .fill(DesignTokens.accentActive.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                                    .strokeBorder(DesignTokens.accentActive.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Drafting indicator
                if isDraftingCount > 0 {
                    HStack(spacing: DesignTokens.spacingSM) {
                        ProgressView()
                            .tint(DesignTokens.accentActive)
                            .scaleEffect(0.8)
                        
                        Text(String(localized: "Nudgy is drafting messages…"))
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .fill(DesignTokens.accentActive.opacity(0.05))
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeOut(duration: 0.3), value: isDraftingCount)
                }

                // Time-horizon sections
                ForEach(TimeHorizon.allCases) { horizon in
                    let items = horizonGroups.items(for: horizon)
                    if !items.isEmpty {
                        horizonSection(for: horizon, items: items)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .padding(.bottom, DesignTokens.spacingXXXL)
        }
        .refreshable { refreshData() }
    }

    // MARK: - Horizon Section Builder
    
    /// Builds a collapsible section for a given time horizon.
    /// Items with actions/drafts get the richer ActionableNudgeRow, others get InboxItemRow.
    private func horizonSection(for horizon: TimeHorizon, items: [NudgeItem]) -> some View {
        CollapsibleNudgeSection(
            horizon: horizon,
            count: items.count,
            accentColor: horizon.accentColor,
            isExpanded: Binding(
                get: { expandedSections.contains(horizon) },
                set: { newValue in
                    if newValue {
                        expandedSections.insert(horizon)
                    } else {
                        expandedSections.remove(horizon)
                    }
                }
            )
        ) {
            ForEach(items, id: \.id) { item in
                itemRow(for: item, in: horizon)
            }
        }
    }
    
    /// Picks the right row component for an item based on whether it has actions/drafts.
    /// Wraps each row in SwipeableRow for gesture-based actions.
    @ViewBuilder
    private func itemRow(for item: NudgeItem, in horizon: TimeHorizon) -> some View {
        if horizon == .doneToday {
            // Done items — no swipe actions
            InboxItemRow(
                item: item,
                onTap: { editingItem = item },
                onDone: nil,
                onSnooze: nil,
                onBreakDown: nil
            )
        } else if (item.hasAction || item.hasDraft) {
            // Actionable items — richer row with swipe
            SwipeableRow(
                content: {
                    ActionableNudgeRow(
                        item: item,
                        onTap: { editingItem = item },
                        onAction: { performAction(item) },
                        onDone: { markDoneWithUndo(item) },
                        onViewDraft: { showDraftFor = item }
                    )
                },
                onSwipeLeading: { markDoneWithUndo(item) },
                onSwipeTrailing: horizon != .snoozed ? { showSnoozeFor = item } : nil
            )
        } else if horizon == .snoozed {
            // Snoozed items — swipe to done only
            SwipeableRow(
                content: {
                    InboxItemRow(
                        item: item,
                        onTap: { editingItem = item },
                        onDone: { markDoneWithUndo(item) },
                        onSnooze: nil,
                        onBreakDown: nil
                    )
                },
                onSwipeLeading: { markDoneWithUndo(item) }
            )
        } else {
            // Regular active items — full swipe (done + snooze)
            SwipeableRow(
                content: {
                    InboxItemRow(
                        item: item,
                        onTap: { editingItem = item },
                        onDone: { markDoneWithUndo(item) },
                        onSnooze: { showSnoozeFor = item },
                        onBreakDown: { showBreakdownFor = item }
                    )
                },
                onSwipeLeading: { markDoneWithUndo(item) },
                onSwipeTrailing: { showSnoozeFor = item }
            )
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()

            PenguinSceneView(
                size: .large,
                expressionOverride: .sleeping,
                accentColorOverride: DesignTokens.textTertiary
            )

            VStack(spacing: DesignTokens.spacingSM) {
                Text(String(localized: "No nudges yet"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)

                Text(String(localized: "Talk to Nudgy to create your first nudge"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                // Navigate to Nudgy tab
                NotificationCenter.default.post(name: .nudgeOpenChat, object: nil)
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "bubble.left.fill")
                    Text(String(localized: "Talk to Nudgy"))
                }
                .font(AppTheme.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.spacingXL)
                .padding(.vertical, DesignTokens.spacingMD)
                .background(
                    Capsule()
                        .fill(DesignTokens.accentActive)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Actions

    private func performAction(_ item: NudgeItem) {
        guard let actionType = item.actionType else { return }
        HapticService.shared.actionButtonTap()
        ActionService.perform(action: actionType, item: item)
    }

    // MARK: - Undo

    private func markDoneWithUndo(_ item: NudgeItem) {
        undoPreviousSortOrder = item.sortOrder
        repository?.markDone(item)
        HapticService.shared.swipeDone()

        undoItem = item
        undoTimerTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showUndoToast = true
        }
        undoTimerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            dismissUndoToast()
        }

        refreshData()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        syncLiveActivity()
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
        withAnimation(.easeOut(duration: 0.25)) {
            showUndoToast = false
        }
        undoItem = nil
    }

    private var undoToastView: some View {
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
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(DesignTokens.cardSurface.opacity(0.5))
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.5), radius: 16, y: 4)
            }
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.bottom, 80)
        }
    }

    // MARK: - Helpers

    private func setupRepository() {
        if repository == nil {
            repository = NudgeRepository(modelContext: modelContext)
        }
    }

    private func refreshData() {
        guard let repository else { return }
        let grouped = repository.fetchAllGrouped()

        // Use time-horizon grouper for ADHD-optimized layout
        horizonGroups = TimeHorizonGrouper.group(
            active: grouped.active,
            snoozed: grouped.snoozed,
            doneToday: grouped.doneToday
        )
    }
    
    // MARK: - Draft Generation
    
    private func triggerDraftGeneration() {
        guard let repository else { return }
        draftGenerationTask?.cancel()
        draftGenerationTask = Task {
            // Find actionable items (text/email) without drafts
            let allActive = horizonGroups.allActive
            let needsDraft = allActive.filter { item in
                guard let actionType = item.actionType,
                      actionType == .text || actionType == .email else { return false }
                return !item.hasDraft
            }
            
            guard !needsDraft.isEmpty else { return }
            
            isDraftingCount = needsDraft.count
            
            for item in needsDraft {
                guard !Task.isCancelled else { break }
                await DraftService.shared.generateDraftIfNeeded(
                    for: item,
                    isPro: settings.isPro,
                    repository: repository,
                    senderName: settings.userName.isEmpty ? nil : settings.userName
                )
                isDraftingCount -= 1
                // Refresh to surface newly-drafted items at the top of their group
                refreshData()
            }
            
            isDraftingCount = 0
        }
    }
    
    // MARK: - AI Insight
    
    private func generateAIInsight() {
        let allActive = horizonGroups.allActive
        let totalActive = allActive.count
        guard totalActive > 0, AIService.shared.isAvailable else {
            aiInsight = nil
            return
        }
        guard !isGeneratingInsight else { return }
        isGeneratingInsight = true
        
        Task {
            let taskSummary = allActive.prefix(5).map { item in
                let emoji = item.emoji ?? "📌"
                let age = Calendar.current.dateComponents([.day], from: item.createdAt, to: Date()).day ?? 0
                return "\(emoji) \(item.content) (age: \(age)d)"
            }.joined(separator: "\n")
            
            let overdueCount = allActive.filter { $0.accentStatus == .overdue }.count
            let staleCount = allActive.filter { $0.accentStatus == .stale }.count
            let draftedCount = allActive.filter { $0.hasDraft }.count
            
            let line = await NudgyDialogueEngine.shared.smartIdleChatter(
                currentTask: "User has \(totalActive) active tasks (\(overdueCount) overdue, \(staleCount) stale, \(draftedCount) with drafts ready):\n\(taskSummary)",
                activeCount: totalActive
            )
            
            withAnimation(.easeOut(duration: 0.3)) {
                aiInsight = line
            }
            isGeneratingInsight = false
        }
    }
    
    // MARK: - Live Activity Sync
    
    /// Sync the Live Activity with current Nudges data directly from this view.
    private func syncLiveActivity() {
        nudgesLog.info("syncLiveActivity called — liveActivityEnabled: \(self.settings.liveActivityEnabled)")
        guard settings.liveActivityEnabled else { return }
        
        let allActive = horizonGroups.allActive
        nudgesLog.info("syncLiveActivity — allActive count: \(allActive.count)")
        guard let topItem = allActive.first else {
            Task { await LiveActivityManager.shared.endIfEmpty() }
            return
        }
        
        let emoji = topItem.emoji ?? "📌"
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
    
    /// Prompt user to enable Live Activity if they haven't been asked and have active tasks.
    private func promptLiveActivityIfNeeded() {
        let totalActive = horizonGroups.activeCount
        guard totalActive >= 1,
              !settings.liveActivityEnabled,
              !settings.liveActivityPromptShown else {
            showLiveActivityPrompt = false
            return
        }
        withAnimation(.easeOut(duration: 0.3)) {
            showLiveActivityPrompt = true
        }
    }
    
    /// Live Activity opt-in banner
    private var liveActivityPromptBanner: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "platter.filled.top.and.arrow.up.iphone")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignTokens.accentActive)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Live Activity"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(String(localized: "See your current task on Lock Screen & Dynamic Island"))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showLiveActivityPrompt = false
                    }
                    settings.liveActivityPromptShown = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: DesignTokens.spacingSM) {
                Button {
                    settings.liveActivityEnabled = true
                    settings.liveActivityPromptShown = true
                    withAnimation(.easeOut(duration: 0.25)) {
                        showLiveActivityPrompt = false
                    }
                    syncLiveActivity()
                } label: {
                    Text(String(localized: "Enable"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(
                            Capsule().fill(DesignTokens.accentActive)
                        )
                }
                .buttonStyle(.plain)
                
                Button {
                    settings.liveActivityPromptShown = true
                    withAnimation(.easeOut(duration: 0.25)) {
                        showLiveActivityPrompt = false
                    }
                } label: {
                    Text(String(localized: "Not now"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.spacingMD)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(DesignTokens.accentActive.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .strokeBorder(DesignTokens.accentActive.opacity(0.15), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Actionable Nudge Row (items Nudgy prepared actions for)

struct ActionableNudgeRow: View {

    let item: NudgeItem
    var onTap: () -> Void = {}
    var onAction: (() -> Void)?
    var onDone: (() -> Void)?
    var onViewDraft: (() -> Void)?

    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }

    private var actionLabel: String {
        switch item.actionType {
        case .call:     return String(localized: "Call")
        case .text:     return String(localized: "Text")
        case .email:    return String(localized: "Email")
        case .openLink: return String(localized: "Open")
        case nil:       return String(localized: "Act")
        }
    }

    private var actionIcon: String {
        item.actionType?.icon ?? "bolt.fill"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // Top row: emoji + content + done button
                HStack(spacing: DesignTokens.spacingMD) {
                    Text(item.emoji ?? "📋")
                        .font(.system(size: 22))
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                        Text(item.content)
                            .font(AppTheme.body)
                            .foregroundStyle(DesignTokens.textPrimary)
                            .lineLimit(2)

                        if let contact = item.contactName, !contact.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                Text(contact)
                            }
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }

                    Spacer()

                    if let onDone {
                        Button {
                            onDone()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DesignTokens.accentComplete)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(DesignTokens.accentComplete.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Draft preview (if Nudgy drafted something)
                if item.hasDraft, let draft = item.aiDraft {
                    Button {
                        onViewDraft?()
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignTokens.accentActive)

                            Text(draft)
                                .font(AppTheme.footnote)
                                .foregroundStyle(DesignTokens.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .padding(DesignTokens.spacingSM)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                                .fill(DesignTokens.accentActive.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Action button
                if let onAction, item.hasAction {
                    Button {
                        onAction()
                    } label: {
                        HStack(spacing: DesignTokens.spacingSM) {
                            Image(systemName: actionIcon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(actionLabel)
                                .font(AppTheme.body.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.spacingSM + 2)
                        .background(
                            Capsule()
                                .fill(DesignTokens.accentActive)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.spacingMD)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(DesignTokens.cardSurface.opacity(0.4))

                    // Accent glow
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.accentActive.opacity(0.06), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignTokens.accentActive.opacity(0.25),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Draft Preview Sheet

struct DraftPreviewSheet: View {

    let item: NudgeItem
    let onSend: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Nudgy's Draft"))
                        .font(AppTheme.headline)
                        .foregroundStyle(DesignTokens.textPrimary)

                    if let contact = item.contactName {
                        Text(String(localized: "For \(contact)"))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }

            // Subject (for emails)
            if let subject = item.aiDraftSubject, !subject.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Subject"))
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                        .textCase(.uppercase)

                    Text(subject)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Draft body
            if let draft = item.aiDraft {
                ScrollView {
                    Text(draft)
                        .font(AppTheme.body)
                        .foregroundStyle(DesignTokens.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()

            // Send button
            Button {
                onSend()
                dismiss()
            } label: {
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: item.actionType?.icon ?? "paperplane.fill")
                    Text(String(localized: "Send"))
                }
                .font(AppTheme.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.spacingMD)
                .background(
                    Capsule()
                        .fill(DesignTokens.accentActive)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.spacingLG)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NudgeItem.self, BrainDump.self, configurations: config)

    let ctx = container.mainContext
    let item1 = NudgeItem(content: "Text Sarah about Saturday plans", emoji: "💬", actionType: .text, actionTarget: "555-1234", contactName: "Sarah", sortOrder: 1)
    item1.aiDraft = "Hey Sarah! Just wanted to check in about Saturday — are we still on for brunch at 11?"
    ctx.insert(item1)

    let item2 = NudgeItem(content: "Email landlord about lease renewal", emoji: "📧", actionType: .email, actionTarget: "landlord@email.com", contactName: "Mr. Johnson", sortOrder: 2)
    item2.aiDraft = "Hi Mr. Johnson, I'm writing to inquire about the lease renewal for my apartment."
    item2.aiDraftSubject = "Lease Renewal Inquiry"
    ctx.insert(item2)

    ctx.insert(NudgeItem(content: "Buy dog food", emoji: "🐶", sortOrder: 3))
    ctx.insert(NudgeItem(content: "Read Jake's article", emoji: "📖", sortOrder: 4))

    return NudgesView()
        .modelContainer(container)
        .environment(AppSettings())
        .environment(PenguinState())
}
