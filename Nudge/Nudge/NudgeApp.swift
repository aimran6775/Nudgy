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
    // MARK: - SwiftData (per-user)
    @State private var activeModelContainer: ModelContainer?
    @State private var syncEngine: CloudKitSyncEngine?
    @State private var isActivating = false
    
    // MARK: - Services
    
    @State private var appSettings = AppSettings()
    @State private var accentSystem = AccentColorSystem.shared
    @State private var purchaseService = PurchaseService.shared
    @State private var penguinState = PenguinState()
    @State private var authSession = AuthSession()
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            TimeAwareAccentWrapper {
                appRoot
                    .onAppear(perform: bootstrapGlobal)
                    .onChange(of: authSession.state) { _, newValue in
                        switch newValue {
                        case .signedIn(let user):
                            if activeModelContainer == nil {
                                Task { await activateUser(user) }
                            }
                        case .signedOut:
                            activeModelContainer = nil
                            syncEngine = nil
                            appSettings.activeUserID = nil
                            NudgyMemory.shared.setActiveUser(id: nil)
                            if LiveActivityManager.shared.isRunning {
                                Task { await LiveActivityManager.shared.endAll() }
                            }
                        case .checking:
                            break
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        onForeground()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .nudgeDataChanged)) { _ in
                        Task { await syncEngine?.syncAll() }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .nudgyMemoryChanged)) { _ in
                        Task { await syncEngine?.syncAll() }
                    }
            }
            .environment(appSettings)
            .environment(accentSystem)
            .environment(penguinState)
            .environment(authSession)
        }
        .backgroundTask(.appRefresh("com.tarsitgroup.nudge.liveActivityRefresh")) {
            await handleLiveActivityRefresh()
        }
    }

    // MARK: - Root View (Intro → Auth → Onboarding → Main)

    @ViewBuilder
    private var appRoot: some View {
        if !appSettings.hasSeenIntro {
            IntroView()
        } else {
            switch authSession.state {
            case .checking:
                ProgressView().preferredColorScheme(.dark)

            case .signedOut:
                AuthGateView()

            case .signedIn(let user):
                if let container = activeModelContainer {
                    Group {
                        if appSettings.hasCompletedOnboarding {
                            ContentView()
                        } else {
                            OnboardingView()
                        }
                    }
                    .modelContainer(container)
                    .onAppear {
                        if appSettings.activeUserID != user.userID {
                            appSettings.activeUserID = user.userID
                        }
                    }
                } else {
                    ProgressView().preferredColorScheme(.dark)
                        .onAppear {
                            if activeModelContainer == nil {
                                Task { await activateUser(user) }
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - Lifecycle
    
    /// Called once on first app launch (device-global bootstraps).
    private func bootstrapGlobal() {
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

        // Start auth bootstrap
        authSession.bootstrap()
        
        // Reset daily counters if needed (scoped once user ID is known)
        appSettings.resetDailyCountersIfNeeded()
        
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

        guard let container = activeModelContainer else { return }

        let repository = NudgeRepository(modelContext: container.mainContext)
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

        Task { await syncEngine?.syncAll() }
    }
    
    // MARK: - Background Tasks
    
    /// Schedule a background app refresh for Live Activity time-of-day gradient updates.
    private func scheduleLiveActivityRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.tarsitgroup.nudge.liveActivityRefresh")
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
        guard activeModelContainer != nil else { return }
        let manager = LiveActivityManager.shared
        
        if manager.isRunning {
            // Update time-of-day gradient strip
            await manager.updateTimeOfDay()
        } else if appSettings.liveActivityEnabled {
            // Activity expired — restart it with current task
            guard let container = activeModelContainer else { return }
            let repository = NudgeRepository(modelContext: container.mainContext)
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

    // MARK: - Per-user activation

    private func activateUser(_ user: AuthSession.UserContext) async {
        guard !isActivating else { return }
        isActivating = true
        defer { isActivating = false }
        #if DEBUG
        print("🔑 activateUser: start — userID=\(user.userID), ck=\(user.cloudKitAvailable)")
        #endif
        // Apply per-user scoping.
        appSettings.activeUserID = user.userID
        if let name = user.displayName, !name.isEmpty {
            appSettings.userName = name
        }

        // Per-user memory storage.
        NudgyMemory.shared.setActiveUser(id: user.userID)
        NudgyEngine.shared.syncUserName(appSettings.userName)
        #if DEBUG
        print("🔑 activateUser: building container")
        #endif

        // Build per-user container.
        let container = makePerUserModelContainer(userID: user.userID)
        activeModelContainer = container
        #if DEBUG
        print("🔑 activateUser: container ready, bootstrapping rewards")
        #endif

        // Bootstrap reward system per user store.
        RewardService.shared.bootstrap(context: container.mainContext)

        // Create sync engine only when CloudKit is available
        if user.cloudKitAvailable {
            #if DEBUG
            print("🔑 activateUser: creating sync engine")
            #endif
            syncEngine = CloudKitSyncEngine(modelContext: container.mainContext, userID: user.userID)
        }
        #if DEBUG
        print("🔑 activateUser: ingesting share items")
        #endif

        // Ingest share items + resurface snoozes
        let repository = NudgeRepository(modelContext: container.mainContext)
        repository.ingestFromShareExtension()
        repository.resurfaceExpiredSnoozes()
        
        // DEBUG: Seed test tasks when using -seedTasks flag (for Live Activity testing)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedTasks") {
            let existing = repository.fetchActiveQueue()
            if existing.isEmpty {
                let testItem = NudgeItem(
                    content: "Call the dentist",
                    sourceType: .manual,
                    emoji: "📞",
                    sortOrder: 0,
                    priority: .medium
                )
                container.mainContext.insert(testItem)
                
                let testItem2 = NudgeItem(
                    content: "Buy groceries for dinner",
                    sourceType: .manual,
                    emoji: "🛒",
                    sortOrder: 1,
                    priority: .low
                )
                container.mainContext.insert(testItem2)
                
                let testItem3 = NudgeItem(
                    content: "Review pull request",
                    sourceType: .manual,
                    emoji: "💻",
                    sortOrder: 2,
                    priority: .high
                )
                container.mainContext.insert(testItem3)
                
                try? container.mainContext.save()
                print("🧪 DEBUG: Seeded 3 test tasks for Live Activity testing")
            }
        }
        #endif

        // Initial sync (if engine exists)
        await syncEngine?.syncAll()
        #if DEBUG
        print("🔑 activateUser: DONE")
        #endif
    }

    private func makePerUserModelContainer(userID: String) -> ModelContainer {
        let schema = Schema([
            NudgeItem.self,
            BrainDump.self,
            NudgyWardrobe.self,
        ])

        let baseURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupID.suiteName
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        let storeURL = baseURL.appendingPathComponent("nudge_\(userID).store")
        // Disable SwiftData's automatic CloudKit mirroring — we sync manually
        // via CloudKitSyncEngine. Without .none, SwiftData enforces CloudKit
        // schema rules (all attributes optional) which our models don't satisfy.
        let configuration = ModelConfiguration(
            "nudge_\(userID)",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("⚠️ Per-user store failed — falling back to in-memory: \(error)")
            let fallback = ModelConfiguration(
                "nudge_fallback",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return (try? ModelContainer(for: schema, configurations: [fallback])) ?? {
                fatalError("Could not create in-memory ModelContainer")
            }()
        }
    }
}
