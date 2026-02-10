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
    /// Returns the number of snowflakes earned (for UI animation).
    @discardableResult
    func recordCompletion(context: ModelContext, isAllClear: Bool = false) -> Int {
        let wardrobe = fetchOrCreateWardrobe(context: context)
        
        // Update streak
        updateStreak(wardrobe: wardrobe)
        
        // Calculate snowflakes earned
        var earned = RewardConstants.snowflakesPerTask
        
        // Streak multiplier
        if wardrobe.currentStreak >= RewardConstants.streakMultiplierThreshold {
            earned *= RewardConstants.streakMultiplier
        }
        
        // All-clear bonus
        if isAllClear {
            earned += RewardConstants.allClearBonus
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
        
        // Regenerate challenges if new day
        regenerateChallengesIfNeeded()
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
