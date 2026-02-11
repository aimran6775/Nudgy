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
        if !authSession.state.isSignedIn {
            NudgyIntroView()
        } else {
            switch authSession.state {
            case .checking, .signedOut:
                ProgressView().preferredColorScheme(.dark)

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
        
        // Auto-generate tasks from active routines
        RoutineService.generateTodaysRoutines(modelContext: container.mainContext)
        
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
        
        // Re-index tasks in Spotlight
        SpotlightIndexer.indexAllTasks(from: repository)
        
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
                    taskEmoji: nextItem.emoji ?? "pin.fill",
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
        
        // Persist user ID for App Intents (out-of-process access)
        IntentModelAccess.setActiveUserID(user.userID)
        
        // Auto-complete onboarding for debug bypass
        #if DEBUG
        if user.userID == "debug-test-user" && !appSettings.hasCompletedOnboarding {
            appSettings.hasSeenIntro = true
            appSettings.hasCompletedOnboarding = true
        }
        #endif

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
        
        // DEBUG: Auto-seed comprehensive test data when store is empty
        #if DEBUG
        do {
            let existing = repository.fetchActiveQueue()
            let snoozed = repository.fetchSnoozed()
            let done = repository.fetchCompletedToday()
            if existing.isEmpty && snoozed.isEmpty && done.isEmpty {
                seedComprehensiveTestData(context: container.mainContext)
            }
        }
        #endif

        // Initial sync (if engine exists)
        await syncEngine?.syncAll()
        
        // Index tasks in Spotlight for system search
        SpotlightIndexer.indexAllTasks(from: repository)
        #if DEBUG
        print("🔑 activateUser: DONE")
        #endif
    }

    private func makePerUserModelContainer(userID: String) -> ModelContainer {
        let schema = Schema([
            NudgeItem.self,
            BrainDump.self,
            NudgyWardrobe.self,
            Routine.self,
            MoodEntry.self,
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
    
    // MARK: - Comprehensive Test Data
    
    #if DEBUG
    private func seedComprehensiveTestData(context: ModelContext) {
        let cal = Calendar.current
        let now = Date()
        
        // Helper dates
        let todayNoon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let today2pm = cal.date(bySettingHour: 14, minute: 0, second: 0, of: now)!
        let today5pm = cal.date(bySettingHour: 17, minute: 0, second: 0, of: now)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let dayAfterTomorrow = cal.date(byAdding: .day, value: 2, to: now)!
        let thisWeek = cal.date(byAdding: .day, value: 4, to: now)!
        let nextWeek = cal.date(byAdding: .day, value: 10, to: now)!
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: now)!
        let fiveDaysAgo = cal.date(byAdding: .day, value: -5, to: now)!
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        
        var order = 0
        
        // ─── 1. CALL action + contact ───
        let call = NudgeItem(
            content: "Call Dr. Patel about prescription refill",
            sourceType: .manual,
            emoji: "phone.fill",
            actionType: .call,
            actionTarget: "+14155551234",
            contactName: "Dr. Patel",
            sortOrder: order,
            priority: .high,
            dueDate: todayNoon,
            estimatedMinutes: 10,
            energyLevel: .medium
        )
        context.insert(call)
        order += 1
        
        // ─── 2. TEXT action + draft ───
        let text = NudgeItem(
            content: "Text Mom happy birthday",
            sourceType: .manual,
            emoji: "gift.fill",
            actionType: .text,
            actionTarget: "+14155559876",
            contactName: "Mom",
            sortOrder: order,
            priority: .high,
            estimatedMinutes: 2,
            energyLevel: .low
        )
        text.aiDraft = "Happy birthday Mom! Hope you have the most amazing day. Love you so much!"
        text.draftGeneratedAt = now
        context.insert(text)
        order += 1
        
        // ─── 3. EMAIL action + draft + subject ───
        let email = NudgeItem(
            content: "Email landlord about lease renewal",
            sourceType: .manual,
            emoji: "envelope.fill",
            actionType: .email,
            actionTarget: "landlord@example.com",
            contactName: "James Chen",
            sortOrder: order,
            priority: .medium,
            dueDate: tomorrow,
            estimatedMinutes: 15,
            energyLevel: .medium
        )
        email.aiDraft = "Hi James,\n\nI hope this message finds you well. I'm writing regarding my lease at 742 Evergreen Terrace, Unit 4B, which is set to expire on August 31st.\n\nI would like to discuss renewal options. Could we set up a time to chat this week?\n\nBest regards"
        email.aiDraftSubject = "Lease Renewal Discussion — Unit 4B"
        email.draftGeneratedAt = now
        context.insert(email)
        order += 1
        
        // ─── 4. OPEN LINK action (shared from Safari) ───
        let link = NudgeItem(
            content: "Read this article on ADHD productivity tips",
            sourceType: .share,
            sourceUrl: "https://www.additudemag.com/adhd-productivity-tips/",
            sourcePreview: "ADDitude Magazine — 15 Science-Backed Strategies for Getting Things Done with ADHD",
            emoji: "book.fill",
            actionType: .openLink,
            actionTarget: "https://www.additudemag.com/adhd-productivity-tips/",
            sortOrder: order,
            priority: .low,
            estimatedMinutes: 8,
            energyLevel: .low
        )
        context.insert(link)
        order += 1
        
        // ─── 5. SEARCH action ───
        let search = NudgeItem(
            content: "Search for standing desk under $300",
            sourceType: .manual,
            emoji: "magnifyingglass",
            actionType: .search,
            actionTarget: "standing desk under $300",
            sortOrder: order,
            priority: .low,
            estimatedMinutes: 15,
            energyLevel: .low
        )
        context.insert(search)
        order += 1
        
        // ─── 6. NAVIGATE action ───
        let navigate = NudgeItem(
            content: "Drive to FedEx to drop off return package",
            sourceType: .manual,
            emoji: "shippingbox.fill",
            actionType: .navigate,
            actionTarget: "FedEx Office, 123 Main St",
            sortOrder: order,
            priority: .medium,
            dueDate: today5pm,
            estimatedMinutes: 30,
            energyLevel: .medium
        )
        context.insert(navigate)
        order += 1
        
        // ─── 7. ADD TO CALENDAR action ───
        let calendar = NudgeItem(
            content: "Schedule dentist appointment for next Thursday",
            sourceType: .manual,
            emoji: "mouth.fill",
            actionType: .addToCalendar,
            sortOrder: order,
            priority: .medium,
            dueDate: thisWeek,
            estimatedMinutes: 5,
            energyLevel: .low
        )
        context.insert(calendar)
        order += 1
        
        // ─── 8. Plain active — today, no action ───
        let plain1 = NudgeItem(
            content: "Take ADHD meds with breakfast",
            sourceType: .manual,
            emoji: "pills.fill",
            sortOrder: order,
            priority: .high,
            estimatedMinutes: 1,
            energyLevel: .low
        )
        context.insert(plain1)
        order += 1
        
        // ─── 9. Plain active — today, medium priority ───
        let plain2 = NudgeItem(
            content: "Water the plants",
            sourceType: .manual,
            emoji: "leaf.fill",
            sortOrder: order,
            priority: .medium,
            estimatedMinutes: 5,
            energyLevel: .low
        )
        context.insert(plain2)
        order += 1
        
        // ─── 10. Due tomorrow — with duration ───
        let tmrw = NudgeItem(
            content: "Finish quarterly report slides",
            sourceType: .manual,
            emoji: "chart.bar.fill",
            sortOrder: order,
            priority: .high,
            dueDate: tomorrow,
            estimatedMinutes: 90,
            scheduledTime: cal.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow),
            energyLevel: .high
        )
        context.insert(tmrw)
        order += 1
        
        // ─── 11. Due tomorrow — low energy ───
        let tmrw2 = NudgeItem(
            content: "Sort through email inbox",
            sourceType: .manual,
            emoji: "envelope.open.fill",
            sortOrder: order,
            priority: .low,
            dueDate: tomorrow,
            estimatedMinutes: 20,
            energyLevel: .low
        )
        context.insert(tmrw2)
        order += 1
        
        // ─── 12. Due this week ───
        let week1 = NudgeItem(
            content: "Book flights for summer vacation",
            sourceType: .manual,
            emoji: "airplane",
            sortOrder: order,
            priority: .medium,
            dueDate: thisWeek,
            estimatedMinutes: 30,
            energyLevel: .medium
        )
        context.insert(week1)
        order += 1
        
        // ─── 13. Due this week + category color ───
        let week2 = NudgeItem(
            content: "Meal prep for the week",
            sourceType: .manual,
            emoji: "fork.knife",
            sortOrder: order,
            priority: .medium,
            dueDate: dayAfterTomorrow,
            estimatedMinutes: 45,
            energyLevel: .medium,
            categoryColorHex: "FF6B6B",
            categoryIcon: "heart.fill"
        )
        context.insert(week2)
        order += 1
        
        // ─── 14. Due later (next week+) ───
        let later = NudgeItem(
            content: "Research new phone plans",
            sourceType: .manual,
            emoji: "iphone",
            sortOrder: order,
            priority: .low,
            dueDate: nextWeek,
            estimatedMinutes: 20,
            energyLevel: .low
        )
        context.insert(later)
        order += 1
        
        // ─── 15. STALE item (3+ days old, no action) ───
        let stale = NudgeItem(
            content: "Clean out the garage",
            sourceType: .manual,
            emoji: "sparkles",
            sortOrder: order,
            priority: .low,
            estimatedMinutes: 60,
            energyLevel: .high
        )
        stale.createdAt = threeDaysAgo
        stale.updatedAt = threeDaysAgo
        context.insert(stale)
        order += 1
        
        // ─── 16. STALE + actionable (5 days old, with CALL) ───
        let staleAction = NudgeItem(
            content: "Call insurance about claim #4829",
            sourceType: .manual,
            emoji: "cross.case.fill",
            actionType: .call,
            actionTarget: "+18005551234",
            contactName: "Blue Cross",
            sortOrder: order,
            priority: .medium,
            estimatedMinutes: 20,
            energyLevel: .high
        )
        staleAction.createdAt = fiveDaysAgo
        staleAction.updatedAt = fiveDaysAgo
        context.insert(staleAction)
        order += 1
        
        // ─── 17. SNOOZED (future — shows in snoozed section) ───
        let snoozed = NudgeItem(
            content: "Review budget spreadsheet",
            sourceType: .manual,
            emoji: "dollarsign.circle.fill",
            sortOrder: order,
            priority: .medium,
            estimatedMinutes: 25,
            energyLevel: .medium
        )
        snoozed.snooze(until: tomorrow)
        context.insert(snoozed)
        order += 1
        
        // ─── 18. SNOOZED (expired — overdue, red accent) ───
        let overdueSnoozed = NudgeItem(
            content: "Submit expense report from last week",
            sourceType: .manual,
            emoji: "doc.text.fill",
            sortOrder: order,
            priority: .high,
            estimatedMinutes: 15,
            energyLevel: .medium
        )
        overdueSnoozed.snooze(until: yesterday)
        context.insert(overdueSnoozed)
        order += 1
        
        // ─── 19. DONE today ───
        let done1 = NudgeItem(
            content: "Morning meditation 10 min",
            sourceType: .manual,
            emoji: "figure.mind.and.body",
            sortOrder: order,
            priority: .medium,
            estimatedMinutes: 10,
            energyLevel: .low
        )
        done1.markDone()
        context.insert(done1)
        order += 1
        
        // ─── 20. DONE today #2 ───
        let done2 = NudgeItem(
            content: "Reply to Sarah's Slack message",
            sourceType: .manual,
            emoji: "message.fill",
            actionType: .text,
            contactName: "Sarah",
            sortOrder: order,
            priority: .low,
            estimatedMinutes: 3,
            energyLevel: .low
        )
        done2.markDone()
        done2.aiDraft = "Hey Sarah! Thanks for the heads up — I'll review those mockups this afternoon and drop my feedback in the thread."
        context.insert(done2)
        order += 1
        
        // ─── 21. DONE today #3 ───
        let done3 = NudgeItem(
            content: "Walk the dog",
            sourceType: .manual,
            emoji: "pawprint.fill",
            sortOrder: order,
            priority: .medium,
            estimatedMinutes: 20,
            energyLevel: .low
        )
        done3.markDone()
        context.insert(done3)
        order += 1
        
        // ─── 22. Voice source item ───
        let voice = NudgeItem(
            content: "Look into that new project management tool Alex mentioned",
            sourceType: .voiceDump,
            emoji: "mic.fill",
            actionType: .search,
            actionTarget: "project management tool for ADHD",
            sortOrder: order,
            priority: .low,
            estimatedMinutes: 10,
            energyLevel: .low
        )
        context.insert(voice)
        order += 1
        
        // ─── 23. Scheduled time item (timeline) ───
        let scheduled = NudgeItem(
            content: "Team standup meeting prep",
            sourceType: .manual,
            emoji: "calendar",
            sortOrder: order,
            priority: .high,
            dueDate: now,
            estimatedMinutes: 5,
            scheduledTime: today2pm,
            energyLevel: .medium
        )
        context.insert(scheduled)
        order += 1
        
        // ─── 24. Follow-up task ───
        let followUp = NudgeItem(
            content: "Send follow-up email after dentist confirms appointment",
            sourceType: .manual,
            emoji: "checklist",
            actionType: .email,
            actionTarget: "dentist@example.com",
            contactName: "Dr. Patel",
            sortOrder: order,
            priority: .medium,
            dueDate: thisWeek,
            estimatedMinutes: 5,
            energyLevel: .low
        )
        followUp.parentTaskContent = "Call Dr. Patel about prescription refill"
        followUp.aiDraft = "Hi Dr. Patel's office,\n\nThank you for confirming my appointment. I wanted to follow up regarding my prescription refill as discussed on the phone.\n\nPlease let me know if you need any additional information.\n\nThank you!"
        followUp.aiDraftSubject = "Follow-up: Prescription Refill & Appointment Confirmation"
        followUp.draftGeneratedAt = now
        context.insert(followUp)
        order += 1
        
        // ─── 25. From routine (references a routine ID) ───
        let routineID = UUID()
        let fromRoutine = NudgeItem(
            content: "Take vitamins",
            sourceType: .manual,
            emoji: "pills.fill",
            sortOrder: order,
            priority: .medium,
            estimatedMinutes: 1,
            routineID: routineID,
            energyLevel: .low
        )
        context.insert(fromRoutine)
        order += 1
        
        // ─── 26. High energy task ───
        let highEnergy = NudgeItem(
            content: "Deep work: Write blog post draft",
            sourceType: .manual,
            emoji: "pencil.line",
            sortOrder: order,
            priority: .medium,
            dueDate: tomorrow,
            estimatedMinutes: 60,
            scheduledTime: cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow),
            energyLevel: .high
        )
        context.insert(highEnergy)
        order += 1
        
        // ─── 27. Share extension source with URL ───
        let shared = NudgeItem(
            content: "Watch this SwiftUI tutorial",
            sourceType: .share,
            sourceUrl: "https://youtube.com/watch?v=example",
            sourcePreview: "Building a Complete iOS App with SwiftUI — 2 hour tutorial",
            emoji: "play.rectangle.fill",
            actionType: .openLink,
            actionTarget: "https://youtube.com/watch?v=example",
            sortOrder: order,
            priority: .low,
            estimatedMinutes: 120,
            energyLevel: .low
        )
        context.insert(shared)
        order += 1
        
        // ─── 28. TEXT action with no draft yet ───
        let textNoDraft = NudgeItem(
            content: "Text Mike about weekend plans",
            sourceType: .manual,
            emoji: "beach.umbrella.fill",
            actionType: .text,
            actionTarget: "+14155552222",
            contactName: "Mike",
            sortOrder: order,
            priority: .low,
            estimatedMinutes: 2,
            energyLevel: .low
        )
        context.insert(textNoDraft)
        order += 1
        
        // ─── 29. Category colored task ───
        let colored = NudgeItem(
            content: "Gym — leg day workout",
            sourceType: .manual,
            emoji: "dumbbell.fill",
            sortOrder: order,
            priority: .medium,
            dueDate: now,
            estimatedMinutes: 45,
            scheduledTime: today5pm,
            energyLevel: .high,
            categoryColorHex: "5E5CE6",
            categoryIcon: "figure.run"
        )
        context.insert(colored)
        order += 1
        
        // ─── 30. Dropped item (won't show in active, but tests data) ───
        let dropped = NudgeItem(
            content: "Learn to play ukulele",
            sourceType: .manual,
            emoji: "guitars.fill",
            sortOrder: order,
            priority: .low
        )
        dropped.drop()
        context.insert(dropped)
        order += 1
        
        // ─── ROUTINE: Morning Routine ───
        let morningRoutine = Routine(
            name: "Morning Routine",
            emoji: "sunrise.fill",
            schedule: .weekdays,
            startHour: 7,
            startMinute: 30,
            steps: [
                RoutineStep(content: "Wake up and stretch", emoji: "sun.max.fill", estimatedMinutes: 5, sortOrder: 0),
                RoutineStep(content: "Shower", emoji: "shower.fill", estimatedMinutes: 10, sortOrder: 1),
                RoutineStep(content: "Breakfast", emoji: "fork.knife", estimatedMinutes: 15, sortOrder: 2),
                RoutineStep(content: "Take meds", emoji: "pills.fill", estimatedMinutes: 1, sortOrder: 3),
                RoutineStep(content: "Review today's tasks", emoji: "checklist", estimatedMinutes: 5, sortOrder: 4),
            ],
            colorHex: "FFB347"
        )
        morningRoutine.id = routineID // Link to the "Take vitamins" task above
        context.insert(morningRoutine)
        
        // ─── ROUTINE: Wind-Down Routine ───
        let eveningRoutine = Routine(
            name: "Bedtime Wind-Down",
            emoji: "moon.stars.fill",
            schedule: .daily,
            startHour: 21,
            startMinute: 0,
            steps: [
                RoutineStep(content: "Put phone on charger", emoji: "bolt.fill", estimatedMinutes: 1, sortOrder: 0),
                RoutineStep(content: "Journal for 5 minutes", emoji: "book.closed.fill", estimatedMinutes: 5, sortOrder: 1),
                RoutineStep(content: "Read a book", emoji: "books.vertical.fill", estimatedMinutes: 15, sortOrder: 2),
                RoutineStep(content: "Lights out", emoji: "moon.zzz.fill", estimatedMinutes: 1, sortOrder: 3),
            ],
            colorHex: "6C5CE7"
        )
        context.insert(eveningRoutine)
        
        try? context.save()
        print("[SEED] DEBUG: Seeded 30 test tasks + 2 routines across all categories")
        print("   [SEED] Action types: CALL, TEXT, EMAIL, LINK, SEARCH, NAVIGATE, CALENDAR")
        print("   [SEED] Time horizons: today, tomorrow, this week, later, snoozed, done")
        print("   [SEED] States: active, stale, overdue-snoozed, done, dropped")
        print("   [SEED] Drafts: 4 items with AI drafts (text, email, follow-up, done)")
        print("   [SEED] Contacts: 6 items with contact names")
        print("   [SEED] Energy: low, medium, high across items")
        print("   [SEED] Routines: Morning (weekdays) + Wind-Down (daily)")
    }
    #endif
}
