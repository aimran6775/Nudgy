//
//  ContentView.swift
//  Nudge
//
//  Root view — iOS 26 native TabView with liquid glass dock.
//  Three tabs: Today (OneThingView), Inbox (NudgyInboxView), Settings.
//  Brain dump is accessed via Nudgy penguin tap — not a tab.
//

import SwiftUI
import SwiftData

// MARK: - Tab Definition

enum NudgeTab: Int, Hashable {
    case nudgy      = 0
    case nudges     = 1
    case you        = 2
}

// MARK: - Root View

struct ContentView: View {
    @State private var selectedTab: NudgeTab = .nudgy
    @State private var showBrainDump = false
    @State private var showQuickAdd = false
    @State private var activeItemCount: Int = 0
    @State private var hasOverdueTasks: Bool = false
    @State private var allClear: Bool = false
    @State private var repository: NudgeRepository?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(PenguinState.self) private var penguinState
    
    /// Smart badge: show exact count for 1-3, cap at 3 for 4+ (avoids overwhelm).
    /// ADHD users respond to manageable numbers, not large counts.
    private var smartBadge: Int {
        if activeItemCount == 0 { return 0 }
        return min(activeItemCount, 3)
    }
    
    /// Dynamic icon for the Nudges tab based on task state.
    private var nudgesTabIcon: String {
        if allClear { return "checkmark.circle" }
        if hasOverdueTasks { return "bell.badge" }
        return "sparkles"
    }
    
    /// Dynamic icon for Nudgy tab based on penguin expression.
    private var nudgyTabExpression: PenguinExpression {
        penguinState.expression
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: NudgeTab.nudgy) {
                NudgyHomeView()
            } label: {
                Label {
                    Text(String(localized: "Nudgy"))
                } icon: {
                    Image("PenguinTab")
                        .renderingMode(.template)
                }
            }

            Tab(String(localized: "Nudges"), systemImage: nudgesTabIcon, value: NudgeTab.nudges) {
                NudgesView()
            }
            .badge(smartBadge)

            Tab(String(localized: "You"), systemImage: "person.fill", value: NudgeTab.you) {
                YouView()
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showBrainDump) {
            BrainDumpView(isPresented: $showBrainDump)
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeOpenBrainDump)) { _ in
            showBrainDump = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeOpenQuickAdd)) { _ in
            showQuickAdd = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeOpenChat)) { _ in
            selectedTab = .nudgy
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeDataChanged)) { _ in
            refreshActiveCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nudgeNotificationAction)) { notification in
            handleNotificationAction(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshActiveCount()
        }
        .onAppear {
            setupRepository()
            refreshActiveCount()
        }
        .onChange(of: selectedTab) { _, _ in refreshActiveCount() }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: - Helpers

    private func setupRepository() {
        if repository == nil {
            repository = NudgeRepository(modelContext: modelContext)
        }
    }

    private func refreshActiveCount() {
        setupRepository()
        let activeQueue = repository?.fetchActiveQueue() ?? []
        activeItemCount = activeQueue.count
        hasOverdueTasks = activeQueue.contains { $0.accentStatus == .overdue }
        allClear = activeQueue.isEmpty
        updateLiveActivity(queue: activeQueue)
    }
    
    // MARK: - Live Activity
    
    private func updateLiveActivity(queue: [NudgeItem]) {
        guard settings.liveActivityEnabled else {
            // If user disabled, end any running activity
            if LiveActivityManager.shared.isRunning {
                Task { await LiveActivityManager.shared.endAll() }
            }
            return
        }
        
        guard let topItem = queue.first else {
            // No active tasks — end activity
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
            // Update existing
            Task {
                await LiveActivityManager.shared.update(
                    taskContent: topItem.content,
                    taskEmoji: emoji,
                    queuePosition: 1,
                    queueTotal: queue.count,
                    accentHex: accentHex,
                    taskID: topItem.id.uuidString
                )
            }
        } else {
            // Start new
            LiveActivityManager.shared.start(
                taskContent: topItem.content,
                taskEmoji: emoji,
                queuePosition: 1,
                queueTotal: queue.count,
                accentHex: accentHex,
                taskID: topItem.id.uuidString
            )
        }
    }

    /// Handle actions from notification taps
    private func handleNotificationAction(_ notification: Foundation.Notification) {
        guard let action = notification.userInfo?["action"] as? String,
              let itemIDString = notification.userInfo?["itemID"] as? String,
              let itemID = UUID(uuidString: itemIDString) else { return }

        setupRepository()

        let allItems = repository?.fetchActiveQueue() ?? []
        let snoozed = repository?.fetchSnoozed() ?? []
        guard let item = (allItems + snoozed).first(where: { $0.id == itemID }) else { return }

        switch action {
        case "markDone":
            repository?.markDone(item)
            HapticService.shared.swipeDone()
        case "snoozeTomorrow":
            repository?.snooze(item, until: .tomorrowMorning)
        case "call":
            ActionService.perform(action: .call, item: item)
        case "text":
            ActionService.perform(action: .text, item: item)
        case "view":
            selectedTab = .nudges
        default:
            break
        }

        refreshActiveCount()
    }

    /// Handle deep links
    private func handleDeepLink(_ url: URL) {
        guard let scheme = url.scheme, scheme == "nudge" else { return }
        
        // Parse query parameters for action deep links
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let itemID = components?.queryItems?.first(where: { $0.name == "id" })?.value

        switch url.host {
        case "brainDump":
            showBrainDump = true
        case "quickAdd":
            showQuickAdd = true
        case "viewTask", "nudges":
            selectedTab = .nudges
        case "allItems", "inbox":
            selectedTab = .nudges
        case "settings", "you":
            selectedTab = .you
        case "chat", "nudgy":
            selectedTab = .nudgy
        case "markDone":
            if let itemID, let uuid = UUID(uuidString: itemID) {
                handleDeepLinkAction(action: "markDone", itemID: uuid)
            }
        case "snooze":
            if let itemID, let uuid = UUID(uuidString: itemID) {
                handleDeepLinkAction(action: "snoozeTomorrow", itemID: uuid)
            }
        default:
            break
        }
    }
    
    /// Handle action deep links from Dynamic Island / Live Activity buttons
    private func handleDeepLinkAction(action: String, itemID: UUID) {
        setupRepository()
        
        let allItems = repository?.fetchActiveQueue() ?? []
        let snoozed = repository?.fetchSnoozed() ?? []
        guard let item = (allItems + snoozed).first(where: { $0.id == itemID }) else { return }
        
        switch action {
        case "markDone":
            repository?.markDone(item)
            HapticService.shared.swipeDone()
            SoundService.shared.playTaskDone()
        case "snoozeTomorrow":
            repository?.snooze(item, until: .tomorrowMorning)
            HapticService.shared.swipeSnooze()
        default:
            break
        }
        
        refreshActiveCount()
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        selectedTab = .nudges
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [NudgeItem.self, BrainDump.self], inMemory: true)
        .environment(AppSettings())
        .environment(PenguinState())
}
