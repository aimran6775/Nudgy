//
//  NudgyWardrobe.swift
//  Nudge
//
//  SwiftData model for tracking unlocked and equipped accessories.
//  Also tracks snowflakes (reward currency), streaks, and level.
//
//  One instance per user (singleton-style, fetched with a descriptor).
//  Created automatically on first app launch by RewardService.
//

import SwiftData
import SwiftUI

// MARK: - NudgyWardrobe Model

@Model
final class NudgyWardrobe {
    
    // MARK: Identity
    
    var id: UUID
    
    // MARK: Reward Currency
    
    /// Snowflakes — earned by completing tasks, spent on accessories.
    var snowflakes: Int
    
    /// Total snowflakes earned all-time (never decremented — for level calculation).
    var lifetimeSnowflakes: Int
    
    // MARK: Streaks
    
    /// Current consecutive-day streak.
    var currentStreak: Int
    
    /// Longest streak ever achieved.
    var longestStreak: Int
    
    /// The last date a task was completed (for streak calculation).
    var lastCompletionDateRaw: Date?
    
    // MARK: Unlocked Accessories
    
    /// Comma-separated IDs of unlocked accessories (SwiftData-safe string storage).
    /// e.g. "scarf-blue,beanie-red,sunglasses"
    var unlockedAccessoriesRaw: String
    
    // MARK: Equipped Accessories
    
    /// Comma-separated IDs of currently equipped accessories.
    /// Max one per slot enforced by RewardService.
    var equippedAccessoriesRaw: String
    
    // MARK: Unlocked Props
    
    /// Comma-separated IDs of environment props unlocked.
    /// e.g. "igloo,campfire"
    var unlockedPropsRaw: String
    
    // MARK: Stats
    
    /// Total tasks completed all-time.
    var totalTasksCompleted: Int
    
    /// Tasks completed today (reset daily).
    var tasksCompletedToday: Int
    
    /// Date of last daily reset.
    var lastDailyResetRaw: Date?
    
    // MARK: Init
    
    init() {
        self.id = UUID()
        self.snowflakes = 0
        self.lifetimeSnowflakes = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastCompletionDateRaw = nil
        self.unlockedAccessoriesRaw = ""
        self.equippedAccessoriesRaw = ""
        self.unlockedPropsRaw = ""
        self.totalTasksCompleted = 0
        self.tasksCompletedToday = 0
        self.lastDailyResetRaw = nil
    }
    
    // MARK: - Computed Properties
    
    /// Set of unlocked accessory IDs.
    var unlockedAccessories: Set<String> {
        get {
            Set(unlockedAccessoriesRaw.split(separator: ",").map(String.init))
                .filter { !$0.isEmpty }
        }
        set {
            unlockedAccessoriesRaw = newValue.sorted().joined(separator: ",")
        }
    }
    
    /// Set of currently equipped accessory IDs.
    var equippedAccessories: Set<String> {
        get {
            Set(equippedAccessoriesRaw.split(separator: ",").map(String.init))
                .filter { !$0.isEmpty }
        }
        set {
            equippedAccessoriesRaw = newValue.sorted().joined(separator: ",")
        }
    }
    
    /// Set of unlocked environment props.
    var unlockedProps: Set<String> {
        get {
            Set(unlockedPropsRaw.split(separator: ",").map(String.init))
                .filter { !$0.isEmpty }
        }
        set {
            unlockedPropsRaw = newValue.sorted().joined(separator: ",")
        }
    }
    
    /// Current level based on lifetime snowflakes.
    var level: Int {
        // Level thresholds: 0, 10, 30, 60, 100, 150, 210, 280, 360, 450...
        // Formula: level n requires n*(n+1)/2 * 10 snowflakes
        var lvl = 0
        var threshold = 0
        while threshold <= lifetimeSnowflakes {
            lvl += 1
            threshold += lvl * 10
        }
        return max(1, lvl)
    }
    
    /// Snowflakes needed for the next level.
    var snowflakesForNextLevel: Int {
        var threshold = 0
        for n in 1...(level + 1) {
            threshold += n * 10
        }
        return threshold
    }
    
    /// Progress toward next level (0.0–1.0).
    var levelProgress: Double {
        let currentLevelThreshold: Int = {
            var t = 0
            for n in 1...level {
                t += n * 10
            }
            return t
        }()
        let nextLevelThreshold = snowflakesForNextLevel
        let range = nextLevelThreshold - currentLevelThreshold
        guard range > 0 else { return 0 }
        let progress = lifetimeSnowflakes - currentLevelThreshold
        return min(1.0, max(0, Double(progress) / Double(range)))
    }
    
    /// Environment mood based on tasks completed today.
    var environmentMood: EnvironmentMood {
        // Check daily reset first
        resetDailyIfNeeded()
        
        if tasksCompletedToday == 0 {
            return .cold
        } else if tasksCompletedToday <= 2 {
            return .warming
        } else {
            return .productive
        }
        // Note: .golden and .stormy are set contextually by RewardService
    }
    
    // MARK: - Daily Reset
    
    private func resetDailyIfNeeded() {
        let calendar = Calendar.current
        if let last = lastDailyResetRaw, calendar.isDateInToday(last) {
            return // Already reset today
        }
        tasksCompletedToday = 0
        lastDailyResetRaw = .now
    }
}
