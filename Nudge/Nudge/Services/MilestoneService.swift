//
//  MilestoneService.swift
//  Nudge
//
//  Checks for and triggers milestone celebrations when the user
//  hits task completion landmarks (10, 25, 50, 100, 250, 500, 1000).
//

import SwiftData
import SwiftUI

@MainActor
enum MilestoneService {
    
    /// Milestone thresholds
    static let milestones = [10, 25, 50, 100, 250, 500, 1000]
    
    /// Check if the user just hit a milestone and return it (if uncelebrated).
    /// Call this after each task completion.
    static func checkForMilestone(context: ModelContext) -> Int? {
        // Count total completed tasks
        let predicate = #Predicate<NudgeItem> { $0.statusRaw == "done" }
        let descriptor = FetchDescriptor<NudgeItem>(predicate: predicate)
        
        guard let count = try? context.fetchCount(descriptor) else { return nil }
        
        // Check if this count matches a milestone
        guard milestones.contains(count) else { return nil }
        
        // Check if already celebrated
        let wardrobeDesc = FetchDescriptor<NudgyWardrobe>()
        guard let wardrobe = try? context.fetch(wardrobeDesc).first else { return nil }
        
        let celebrated = wardrobe.celebratedMilestones
        guard !celebrated.contains(count) else { return nil }
        
        // Mark as celebrated
        var updated = celebrated
        updated.insert(count)
        wardrobe.celebratedMilestones = updated
        try? context.save()
        
        return count
    }
    
    /// Get celebration message for a milestone
    static func message(for milestone: Int) -> (title: String, subtitle: String, emoji: String) {
        switch milestone {
        case 10:
            return (
                String(localized: "First 10! 🎉"),
                String(localized: "You've completed 10 tasks. That's real momentum!"),
                "🔥"
            )
        case 25:
            return (
                String(localized: "Quarter Century! 🌟"),
                String(localized: "25 tasks done. You're building a serious habit."),
                "⭐"
            )
        case 50:
            return (
                String(localized: "Half a Hundred! 🎯"),
                String(localized: "50 tasks conquered. You're unstoppable."),
                "💫"
            )
        case 100:
            return (
                String(localized: "TRIPLE DIGITS! 🏆"),
                String(localized: "100 tasks. Let that sink in. You. Are. Incredible."),
                "🏆"
            )
        case 250:
            return (
                String(localized: "250 Strong! 💎"),
                String(localized: "A quarter thousand. Most people never get here."),
                "💎"
            )
        case 500:
            return (
                String(localized: "Five Hundred! 🚀"),
                String(localized: "500 tasks. You've changed your life."),
                "🚀"
            )
        case 1000:
            return (
                String(localized: "ONE THOUSAND! 👑"),
                String(localized: "You've completed 1,000 tasks. Legend status achieved."),
                "👑"
            )
        default:
            return (
                String(localized: "Milestone! 🎉"),
                String(localized: "\(milestone) tasks completed!"),
                "🎉"
            )
        }
    }
    
    /// Snowflake bonus for reaching a milestone
    static func bonusSnowflakes(for milestone: Int) -> Int {
        switch milestone {
        case 10: return 10
        case 25: return 20
        case 50: return 30
        case 100: return 50
        case 250: return 75
        case 500: return 100
        case 1000: return 200
        default: return 5
        }
    }
}
