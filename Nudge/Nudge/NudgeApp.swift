//
//  NudgeApp.swift
//  Nudge
//
//  Main entry point. Wires up SwiftData, services, and the root view.
//

import SwiftUI
import SwiftData
import TipKit
import BackgroundTasks

@main
struct NudgeApp: App {
    
    // MARK: - SwiftData Container
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            NudgeItem.self,
            BrainDump.self,
            NudgyWardrobe.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If persistent store is corrupt (e.g. after schema migration),
            // fall back to an in-memory container so the app still launches.
            // The user will see an empty state and can re-dump tasks.
            print("⚠️ Persistent store failed — falling back to in-memory: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                // If even in-memory fails, something is fundamentally wrong with the schema.
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
    }()
    
    // MARK: - Services
    
    @State private var appSettings = AppSettings()
    @State private var accentSystem = AccentColorSystem.shared
    @State private var purchaseService = PurchaseService.shared
    @State private var penguinState = PenguinState()
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            TimeAwareAccentWrapper {
                rootView
                    .onAppear(perform: bootstrap)
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: UIApplication.willEnterForegroundNotification
                        )
                    ) { _ in
                        onForeground()
                    }
            }
            .environment(appSettings)
            .environment(accentSystem)
            .environment(penguinState)
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh("com.nudge.app.liveActivityRefresh")) {
            await handleLiveActivityRefresh()
        }
    }
    
    // MARK: - Root View (Onboarding Gate)
    
    @ViewBuilder
    private var rootView: some View {
        if appSettings.hasCompletedOnboarding {
            ContentView()
        } else {
            OnboardingView()
        }
    }
    
    // MARK: - Lifecycle
    
    /// Called once on first app launch
    private func bootstrap() {
        // Configure TipKit
        try? Tips.configure([
            .displayFrequency(.monthly)
        ])
        
        // Pre-warm haptic generators
        HapticService.shared.prepare()
        
        // Load custom sounds
        SoundService.shared.loadSounds()
        
        // Pre-warm AI model for faster first response
        AIService.shared.prewarm()
        
        // Bootstrap NudgyEngine (conversational AI engine)
        NudgyEngine.shared.bootstrap(penguinState: penguinState)
        NudgyEngine.shared.syncUserName(appSettings.userName)
        
        // Bootstrap reward system
        RewardService.shared.bootstrap(context: sharedModelContainer.mainContext)
        
        // Reset daily counters if needed
        appSettings.resetDailyCountersIfNeeded()
        
        // Ingest any pending items from Share Extension
        let repository = NudgeRepository(modelContext: sharedModelContainer.mainContext)
        repository.ingestFromShareExtension()
        repository.resurfaceExpiredSnoozes()
        
        // Check subscription entitlements
        Task {
            purchaseService.startListening()
            await purchaseService.checkEntitlements()
            purchaseService.syncToSettings(appSettings)
        }
        
        // Request notification permission (deferred — will be requested on first snooze)
        // NotificationService handles its own permission flow
    }
    
    /// Called every time the app returns to foreground
    private func onForeground() {
        appSettings.resetDailyCountersIfNeeded()
        
        let repository = NudgeRepository(modelContext: sharedModelContainer.mainContext)
        repository.ingestFromShareExtension()
        repository.resurfaceExpiredSnoozes()
        
        // Schedule stale-item nudge notifications for items older than 3 days
        let activeItems = repository.fetchActiveQueue()
        let staleItems = activeItems.filter { $0.ageInDays >= 3 }
        for item in staleItems.prefix(2) { // Max 2 stale notifications to avoid spam
            NotificationService.shared.scheduleStaleNotification(for: item, settings: appSettings)
        }
        
        // Schedule end-of-day prompt if items remain
        NotificationService.shared.scheduleEndOfDayPrompt(
            remainingCount: activeItems.count,
            settings: appSettings
        )
        
        // Re-check subscription status
        Task {
            await purchaseService.checkEntitlements()
            purchaseService.syncToSettings(appSettings)
        }
        
        // Schedule background refresh for Live Activity time-of-day updates
        if appSettings.liveActivityEnabled {
            scheduleLiveActivityRefresh()
        }
    }
    
    // MARK: - Background Tasks
    
    /// Schedule a background app refresh for Live Activity time-of-day gradient updates.
    private func scheduleLiveActivityRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.nudge.app.liveActivityRefresh")
        // Schedule for next time-of-day transition
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // ~1 hour
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("⚠️ Could not schedule Live Activity refresh: \\(error)")
            #endif
        }
    }
    
    /// Handle background refresh — update Live Activity gradient and restart if expired.
    private func handleLiveActivityRefresh() async {
        let manager = LiveActivityManager.shared
        
        if manager.isRunning {
            // Update time-of-day gradient strip
            await manager.updateTimeOfDay()
        } else if appSettings.liveActivityEnabled {
            // Activity expired — restart it with current task
            let repository = NudgeRepository(modelContext: sharedModelContainer.mainContext)
            if let nextItem = repository.fetchNextItem() {
                let accentHex = AccentColorSystem.shared.hexString(for: nextItem.accentStatus)
                manager.start(
                    taskContent: nextItem.content,
                    taskEmoji: nextItem.emoji ?? "📌",
                    queuePosition: 1,
                    queueTotal: repository.fetchActiveQueue().count,
                    accentHex: accentHex,
                    taskID: nextItem.id.uuidString
                )
            }
        }
        
        // Re-schedule for next update
        scheduleLiveActivityRefresh()
    }
}
