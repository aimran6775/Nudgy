//
//  RewardService.swift
//  Nudge
//
//  Manages the reward loop: earning snowflakes, unlocking accessories,
//  tracking streaks, and updating environment mood.
//
//  Singleton via RewardService.shared. Requires a ModelContext to operate
//  (passed per-call, same pattern as NudgeRepository).
//
//  Call flow:
//    Task completed → RewardService.shared.recordCompletion(context:)
//    Buy accessory  → RewardService.shared.unlock(accessoryID:context:)
//    Equip/unequip  → RewardService.shared.equip(accessoryID:context:)
//

import SwiftData
import SwiftUI

// MARK: - Reward Constants

nonisolated enum RewardConstants {
    /// Snowflakes earned per task completed.
    static let snowflakesPerTask: Int = 2
    
    /// Bonus snowflakes for clearing ALL tasks.
    static let allClearBonus: Int = 5
    
    /// Streak multiplier kicks in at this many consecutive days.
    static let streakMultiplierThreshold: Int = 3
    
    /// Streak multiplier: 2× snowflakes after 3+ day streak.
    static let streakMultiplier: Int = 2
    
    /// Notification posted when snowflakes change (for UI refresh).
    static let snowflakesChangedNotification = Notification.Name("nudgeSnowflakesChanged")
    
    /// Notification posted when an accessory is unlocked.
    static let accessoryUnlockedNotification = Notification.Name("nudgeAccessoryUnlocked")
    
    /// Notification posted when a daily challenge is completed.
    static let challengeCompletedNotification = Notification.Name("nudgeChallengeCompleted")
}

// MARK: - Unlock Result

enum UnlockResult {
    case success(accessoryID: String, remainingSnowflakes: Int)
    case alreadyUnlocked
    case insufficientSnowflakes(have: Int, need: Int)
    case notFound
}

// MARK: - RewardService

@Observable
final class RewardService {
    
    static let shared = RewardService()
    
    // MARK: - Published State (for UI binding)
    
    /// Current snowflake count (mirrors wardrobe, updated on every mutation).
    private(set) var snowflakes: Int = 0
    
    /// Currently equipped accessory IDs (mirrors wardrobe).
    private(set) var equippedAccessories: Set<String> = []
    
    /// All unlocked accessory IDs (mirrors wardrobe).
    private(set) var unlockedAccessories: Set<String> = []
    
    /// Unlocked environment props.
    private(set) var unlockedProps: Set<String> = []
    
    /// Current streak.
    private(set) var currentStreak: Int = 0
    
    /// Current level.
    private(set) var level: Int = 1
    
    /// Progress toward next level (0.0–1.0).
    private(set) var levelProgress: Double = 0
    
    /// Tasks completed today.
    private(set) var tasksCompletedToday: Int = 0
    
    /// Environment mood based on today's productivity.
    private(set) var environmentMood: EnvironmentMood = .cold
    
    /// The stage tier BEFORE the last level-up (for detecting tier changes).
    private(set) var previousStage: StageTier = .bareIce
    
    /// Set to the new tier when a stage-up happens (nil if no recent stage-up).
    private(set) var pendingStageUp: StageTier? = nil
    
    /// Today's daily challenges.
    private(set) var dailyChallenges: [DailyChallenge] = []
    
    /// Fish catches (for aquarium display).
    private(set) var fishCatches: [FishCatch] = []
    
    /// The most recent fish catch (for animation).
    private(set) var lastFishCatch: FishCatch? = nil
    
    /// Unlocked tank decoration IDs.
    private(set) var unlockedDecorations: Set<String> = []
    
    /// Currently placed (visible) tank decoration IDs.
    private(set) var placedDecorations: Set<String> = []
    
    /// Times fish were fed today.
    private(set) var fishFedToday: Int = 0
    
    /// Consecutive days of feeding fish.
    private(set) var feedingStreak: Int = 0
    
    /// Longest feeding streak ever.
    private(set) var longestFeedingStreak: Int = 0
    
    /// Fish happiness level (0.0–1.0) based on feeding today.
    var fishHappiness: Double {
        min(Double(fishFedToday) / 3.0, 1.0)
    }
    
    /// Date the current set of daily challenges was generated.
    private var challengeDate: Date? = nil
    
    private init() {}
    
    // MARK: - Bootstrap
    
    /// Load or create the wardrobe on app launch. Call from NudgeApp.bootstrap().
    func bootstrap(context: ModelContext) {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        syncState(from: wardrobe)
    }
    
    // MARK: - Task Completion Reward
    
    /// Record a task completion — earn snowflakes, update streak, etc.
    /// Pass the completed item to earn species-appropriate fish.
    /// Returns the number of snowflakes earned (for UI animation).
    @discardableResult
    func recordCompletion(context: ModelContext, item: NudgeItem? = nil, isAllClear: Bool = false) -> Int {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        
        // Update streak
        updateStreak(wardrobe: wardrobe)
        
        // Fish economy: determine species and snowflakes
        let species: FishSpecies
        if let item {
            species = FishEconomy.speciesForTask(item)
        } else {
            species = .catfish
        }
        
        // Calculate snowflakes via fish economy
        var earned = FishEconomy.snowflakesForCatch(
            species: species,
            streak: wardrobe.currentStreak,
            isAllClear: isAllClear
        )
        
        // Record the fish catch
        if let item {
            let fishCatch = FishCatch(
                species: species,
                taskContent: item.content,
                taskEmoji: item.emoji ?? "checklist"
            )
            wardrobe.addFishCatch(fishCatch)
            lastFishCatch = fishCatch
        }
        
        // Credit snowflakes
        wardrobe.snowflakes += earned
        wardrobe.lifetimeSnowflakes += earned
        wardrobe.totalTasksCompleted += 1
        wardrobe.tasksCompletedToday += 1
        
        // Detect stage tier change
        let oldStage = StageTier.from(level: level)
        
        // Save and sync
        try? context.save()
        syncState(from: wardrobe)
        
        // Check streak milestone bonus (3, 7, 14, 30 day rewards)
        let streakBonus = checkStreakMilestoneBonus(context: context)
        earned += streakBonus
        
        let newStage = StageTier.from(level: wardrobe.level)
        if newStage.rawValue > oldStage.rawValue {
            previousStage = oldStage
            pendingStageUp = newStage
            NotificationCenter.default.post(name: .nudgeStageUp, object: newStage)
        }
        
        // Update daily challenges
        updateChallengeProgress(tasksToday: wardrobe.tasksCompletedToday, isAllClear: isAllClear)
        
        NotificationCenter.default.post(name: RewardConstants.snowflakesChangedNotification, object: nil)
        
        return earned
    }
    
    // MARK: - Unlock Accessory
    
    /// Attempt to unlock an accessory. Deducts snowflakes if successful.
    func unlock(accessoryID: String, context: ModelContext) -> UnlockResult {
        guard AccessoryCatalog.item(for: accessoryID) != nil else {
            return .notFound
        }
        
        let wardrobe = fetchOrCreateWardrobe(context: context)
        
        // Already unlocked?
        if wardrobe.unlockedAccessories.contains(accessoryID) {
            return .alreadyUnlocked
        }
        
        let cost = AccessoryCatalog.cost(for: accessoryID)
        
        // Can afford?
        guard wardrobe.snowflakes >= cost else {
            return .insufficientSnowflakes(have: wardrobe.snowflakes, need: cost)
        }
        
        // Deduct and unlock
        wardrobe.snowflakes -= cost
        var unlocked = wardrobe.unlockedAccessories
        unlocked.insert(accessoryID)
        wardrobe.unlockedAccessories = unlocked
        
        try? context.save()
        syncState(from: wardrobe)
        
        NotificationCenter.default.post(
            name: RewardConstants.accessoryUnlockedNotification,
            object: accessoryID
        )
        
        return .success(accessoryID: accessoryID, remainingSnowflakes: wardrobe.snowflakes)
    }
    
    // MARK: - Equip / Unequip
    
    /// Toggle equipping an accessory. Enforces one-per-slot.
    func toggleEquip(accessoryID: String, context: ModelContext) {
        guard let item = AccessoryCatalog.item(for: accessoryID) else { return }
        
        let wardrobe = fetchOrCreateWardrobe(context: context)
        var equipped = wardrobe.equippedAccessories
        
        if equipped.contains(accessoryID) {
            // Unequip
            equipped.remove(accessoryID)
        } else {
            // Unequip any existing item in the same slot
            let sameSlotItems = equipped.filter { id in
                AccessoryCatalog.item(for: id)?.slot == item.slot
            }
            for existing in sameSlotItems {
                equipped.remove(existing)
            }
            
            // Equip the new item
            equipped.insert(accessoryID)
        }
        
        wardrobe.equippedAccessories = equipped
        try? context.save()
        syncState(from: wardrobe)
    }
    
    // MARK: - Environment Mood
    
    /// Get the environment mood considering both today's tasks and overdue state.
    func computeMood(tasksCompletedToday: Int, hasOverdue: Bool, isAllClear: Bool) -> EnvironmentMood {
        if hasOverdue {
            return .stormy
        }
        if isAllClear && tasksCompletedToday > 0 {
            return .golden
        }
        if tasksCompletedToday >= 3 {
            return .productive
        }
        if tasksCompletedToday > 0 {
            return .warming
        }
        return .cold
    }
    
    /// Update the mood and sync to state.
    func updateMood(context: ModelContext, hasOverdue: Bool = false, isAllClear: Bool = false) {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        environmentMood = computeMood(
            tasksCompletedToday: wardrobe.tasksCompletedToday,
            hasOverdue: hasOverdue,
            isAllClear: isAllClear
        )
    }
    
    // MARK: - Streak Management
    
    private func updateStreak(wardrobe: NudgyWardrobe) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        if let lastDate = wardrobe.lastCompletionDateRaw {
            let lastDay = calendar.startOfDay(for: lastDate)
            
            if lastDay == today {
                // Already completed today — streak unchanged
                return
            }
            
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysDiff == 1 {
                // Consecutive day — extend streak
                wardrobe.currentStreak += 1
            } else if daysDiff == 2 && wardrobe.canUseStreakFreeze {
                // Missed one day — use streak freeze to save streak
                wardrobe.currentStreak += 1
                wardrobe.streakFreezes -= 1
                wardrobe.freezeUsedToday = true
            } else {
                // Gap too large — reset streak
                wardrobe.currentStreak = 1
            }
        } else {
            // First ever completion
            wardrobe.currentStreak = 1
        }
        
        wardrobe.lastCompletionDateRaw = .now
        wardrobe.longestStreak = max(wardrobe.longestStreak, wardrobe.currentStreak)
        
        // Award streak freeze every 7-day streak
        if wardrobe.currentStreak > 0 && wardrobe.currentStreak % 7 == 0 {
            let today = calendar.startOfDay(for: Date())
            if wardrobe.lastFreezeEarnedDate == nil || !calendar.isDate(wardrobe.lastFreezeEarnedDate!, inSameDayAs: today) {
                wardrobe.streakFreezes = min(wardrobe.streakFreezes + 1, 3) // Max 3 freezes
                wardrobe.lastFreezeEarnedDate = today
            }
        }
    }
    
    // MARK: - Data Access
    
    /// Fetch the single wardrobe record, creating one if it doesn't exist.
    private func fetchOrCreateWardrobe(context: ModelContext) -> NudgyWardrobe {
        let descriptor = FetchDescriptor<NudgyWardrobe>()
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // First launch — create wardrobe
        let wardrobe = NudgyWardrobe()
        context.insert(wardrobe)
        try? context.save()
        return wardrobe
    }
    
    /// Sync observable state from the wardrobe model.
    private func syncState(from wardrobe: NudgyWardrobe) {
        snowflakes = wardrobe.snowflakes
        equippedAccessories = wardrobe.equippedAccessories
        unlockedAccessories = wardrobe.unlockedAccessories
        unlockedProps = wardrobe.unlockedProps
        currentStreak = wardrobe.currentStreak
        level = wardrobe.level
        levelProgress = wardrobe.levelProgress
        tasksCompletedToday = wardrobe.tasksCompletedToday
        environmentMood = wardrobe.environmentMood
        fishCatches = wardrobe.fishCatches
        unlockedDecorations = wardrobe.unlockedDecorations
        placedDecorations = wardrobe.placedDecorations
        fishFedToday = wardrobe.fishFedToday
        feedingStreak = wardrobe.feedingStreak
        longestFeedingStreak = wardrobe.longestFeedingStreak
        
        // Regenerate challenges if new day
        regenerateChallengesIfNeeded()
    }
    
    // MARK: - Feeding
    
    /// Record a fish feeding. Awards snowflakes for feeding streaks.
    /// Returns snowflakes earned from feeding bonus (0 if none).
    @discardableResult
    func recordFeeding(context: ModelContext) -> Int {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        // Reset daily counter if new day
        if let lastFed = wardrobe.lastFedDateRaw {
            let lastFedDay = calendar.startOfDay(for: lastFed)
            if lastFedDay != today {
                wardrobe.fishFedToday = 0
                
                // Update feeding streak
                let daysDiff = calendar.dateComponents([.day], from: lastFedDay, to: today).day ?? 0
                if daysDiff == 1 {
                    wardrobe.feedingStreak += 1
                } else if daysDiff > 1 {
                    wardrobe.feedingStreak = 1
                }
            }
        } else {
            // First ever feed
            wardrobe.feedingStreak = 1
        }
        
        wardrobe.fishFedToday += 1
        wardrobe.lastFedDateRaw = .now
        wardrobe.longestFeedingStreak = max(wardrobe.longestFeedingStreak, wardrobe.feedingStreak)
        
        // Streak bonus snowflakes
        var bonus = 0
        
        // First feed of the day: streak milestone bonus
        if wardrobe.fishFedToday == 1 {
            if wardrobe.feedingStreak >= 7 {
                bonus = 5  // 7+ day feeding streak: +5 ❄️
            } else if wardrobe.feedingStreak >= 3 {
                bonus = 2  // 3+ day feeding streak: +2 ❄️
            }
        }
        
        // Feed 3 times in a day bonus
        if wardrobe.fishFedToday == 3 {
            bonus += 3  // Full belly bonus: +3 ❄️
        }
        
        if bonus > 0 {
            wardrobe.snowflakes += bonus
            wardrobe.lifetimeSnowflakes += bonus
        }
        
        try? context.save()
        syncState(from: wardrobe)
        
        if bonus > 0 {
            NotificationCenter.default.post(name: RewardConstants.snowflakesChangedNotification, object: nil)
        }
        
        return bonus
    }
    
    /// Snowflake bonus description for current feeding streak.
    var feedingStreakBonusLabel: String? {
        if feedingStreak >= 7 {
            return String(localized: "+5 ❄️ per day (7-day feeding streak!)")
        } else if feedingStreak >= 3 {
            return String(localized: "+2 ❄️ per day (3-day feeding streak)")
        }
        return nil
    }
    
    // MARK: - Streak Snowflake Milestones
    
    /// Snowflakes bonus for task completion streak milestones.
    /// Called after streak is updated in recordCompletion.
    func checkStreakMilestoneBonus(context: ModelContext) -> Int {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        let streak = wardrobe.currentStreak
        var bonus = 0
        
        // Streak milestones: 3, 7, 14, 30 days
        let milestones: [(Int, Int)] = [(3, 5), (7, 15), (14, 30), (30, 75)]
        for (milestone, reward) in milestones {
            if streak == milestone {
                bonus = reward
                break
            }
        }
        
        if bonus > 0 {
            wardrobe.snowflakes += bonus
            wardrobe.lifetimeSnowflakes += bonus
            try? context.save()
            syncState(from: wardrobe)
        }
        
        return bonus
    }
    
    // MARK: - Tank Decorations
    
    /// Unlock a tank decoration by spending snowflakes.
    func unlockDecoration(_ decoID: String, cost: Int, context: ModelContext) {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        guard wardrobe.snowflakes >= cost else { return }
        guard !wardrobe.unlockedDecorations.contains(decoID) else { return }
        
        wardrobe.snowflakes -= cost
        var unlocked = wardrobe.unlockedDecorations
        unlocked.insert(decoID)
        wardrobe.unlockedDecorations = unlocked
        
        // Auto-place when bought
        var placed = wardrobe.placedDecorations
        placed.insert(decoID)
        wardrobe.placedDecorations = placed
        
        try? context.save()
        syncState(from: wardrobe)
    }
    
    /// Toggle a decoration's placement in the tank.
    func toggleDecoration(_ decoID: String, context: ModelContext) {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        var placed = wardrobe.placedDecorations
        if placed.contains(decoID) {
            placed.remove(decoID)
        } else {
            placed.insert(decoID)
        }
        wardrobe.placedDecorations = placed
        try? context.save()
        syncState(from: wardrobe)
    }
    
    // MARK: - Stage Up
    
    /// Acknowledge the stage-up celebration was shown.
    func acknowledgeStageUp() {
        pendingStageUp = nil
    }
    
    // MARK: - Daily Challenges
    
    /// Regenerate daily challenges if the date has changed.
    private func regenerateChallengesIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        
        if challengeDate != today {
            dailyChallenges = ChallengeGenerator.generateDaily(
                level: level,
                streak: currentStreak
            )
            challengeDate = today
        }
    }
    
    /// Update challenge progress after a task completion.
    private func updateChallengeProgress(tasksToday: Int, isAllClear: Bool) {
        var anyCompleted = false
        
        for i in dailyChallenges.indices {
            guard !dailyChallenges[i].isCompleted else { continue }
            
            var completed = false
            
            switch dailyChallenges[i].requirement {
            case .completeTasks(let count):
                completed = tasksToday >= count
            case .clearAll:
                completed = isAllClear
            case .maintainStreak:
                completed = currentStreak > 0
            case .completeBeforeNoon:
                let hour = Calendar.current.component(.hour, from: .now)
                completed = hour < 12
            case .brainDump:
                break  // Set externally via completeBrainDumpChallenge()
            }
            
            if completed {
                dailyChallenges[i].isCompleted = true
                anyCompleted = true
            }
        }
        
        if anyCompleted {
            NotificationCenter.default.post(
                name: RewardConstants.challengeCompletedNotification,
                object: nil
            )
        }
    }
    
    /// Mark the brain dump challenge as completed (called from brain dump flow).
    func completeBrainDumpChallenge(context: ModelContext) {
        guard let idx = dailyChallenges.firstIndex(where: { $0.id == "brain-dump" && !$0.isCompleted }) else { return }
        
        dailyChallenges[idx].isCompleted = true
        
        // Award bonus fish
        let wardrobe = fetchOrCreateWardrobe(context: context)
        wardrobe.snowflakes += dailyChallenges[idx].bonusFish
        wardrobe.lifetimeSnowflakes += dailyChallenges[idx].bonusFish
        try? context.save()
        syncState(from: wardrobe)
        
        NotificationCenter.default.post(
            name: RewardConstants.challengeCompletedNotification,
            object: nil
        )
    }
    
    /// Award bonus fish for completed challenges. Call after showing challenge-complete UI.
    func claimChallengeRewards(context: ModelContext) {
        let bonus = dailyChallenges.filter(\.isCompleted).reduce(0) { $0 + $1.bonusFish }
        guard bonus > 0 else { return }
        
        let wardrobe = fetchOrCreateWardrobe(context: context)
        // Note: challenge rewards are auto-credited; this is for explicit claim flow if needed
    }
}
