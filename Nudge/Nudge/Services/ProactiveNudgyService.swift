//
//  ProactiveNudgyService.swift
//  Nudge
//
//  Nudgy doesn't wait for you — it initiates.
//  Morning briefing, stale task nudging, pattern detection,
//  evening review prompts, and contextual suggestions.
//
//  Called from NudgeApp.onForeground() and NudgyHomeView.
//

import Foundation
import SwiftData

// MARK: - Briefing Content

/// A proactive briefing from Nudgy.
struct NudgyBriefing: Sendable {
    let greeting: String
    let taskSummary: String
    let topSuggestion: String?
    let draftReadyCount: Int
    let overdueItems: [BriefingItem]
    let staleItems: [BriefingItem]
    let todayItems: [BriefingItem]
    let insightLine: String?
    
    /// Total items needing attention.
    var attentionCount: Int { overdueItems.count + staleItems.count }
    
    /// Whether there's meaningful content to show.
    var hasContent: Bool { !todayItems.isEmpty || !overdueItems.isEmpty || !staleItems.isEmpty }
    
    struct BriefingItem: Sendable {
        let emoji: String
        let content: String
        let age: Int
        let actionType: String?
        let hasDraft: Bool
    }
}

// MARK: - Snooze Pattern

/// Detected pattern of repeated snoozing on a task.
struct SnoozePattern: Sendable {
    let taskContent: String
    let taskEmoji: String
    let snoozeCount: Int
    let suggestion: String
}

// MARK: - ProactiveNudgyService

@MainActor
enum ProactiveNudgyService {
    
    // MARK: - Morning Briefing
    
    /// Generate a morning briefing for the user.
    static func generateBriefing(modelContext: ModelContext) -> NudgyBriefing {
        let repo = NudgeRepository(modelContext: modelContext)
        let grouped = repo.fetchAllGrouped()
        let active = grouped.active
        let snoozed = grouped.snoozed
        let doneToday = grouped.doneToday
        
        let hour = Calendar.current.component(.hour, from: .now)
        let userName = NudgyMemory.shared.store.userName
        
        // Greeting based on time of day
        let greeting: String
        let namePrefix = userName.map { "\($0), " } ?? ""
        switch hour {
        case 5..<12:
            greeting = "Good morning, \(namePrefix)🌅"
        case 12..<17:
            greeting = "Good afternoon, \(namePrefix)☀️"
        case 17..<21:
            greeting = "Good evening, \(namePrefix)🌙"
        default:
            greeting = "Hey \(namePrefix)🌌"
        }
        
        // Task summary
        let totalActive = active.count
        let snoozedCount = snoozed.count
        let doneCount = doneToday.count
        
        var summaryParts: [String] = []
        if totalActive > 0 { summaryParts.append("\(totalActive) active") }
        if snoozedCount > 0 { summaryParts.append("\(snoozedCount) snoozed") }
        if doneCount > 0 { summaryParts.append("\(doneCount) done today") }
        let taskSummary = summaryParts.isEmpty ? "Your slate is clean! 🐧" : summaryParts.joined(separator: " · ")
        
        // Overdue items
        let overdue = active.filter { $0.isOverdue }
        let overdueItems = overdue.prefix(3).map { item in
            NudgyBriefing.BriefingItem(
                emoji: item.emoji ?? "doc.text.fill",
                content: item.content,
                age: item.ageInDays,
                actionType: item.actionTypeRaw,
                hasDraft: item.hasDraft
            )
        }
        
        // Stale items (3+ days without action)
        let stale = active.filter { $0.isStale && !$0.isOverdue }
        let staleItems = stale.prefix(3).map { item in
            NudgyBriefing.BriefingItem(
                emoji: item.emoji ?? "doc.text.fill",
                content: item.content,
                age: item.ageInDays,
                actionType: item.actionTypeRaw,
                hasDraft: item.hasDraft
            )
        }
        
        // Today items (due today or top of queue)
        let today = active.prefix(5).map { item in
            NudgyBriefing.BriefingItem(
                emoji: item.emoji ?? "doc.text.fill",
                content: item.content,
                age: item.ageInDays,
                actionType: item.actionTypeRaw,
                hasDraft: item.hasDraft
            )
        }
        
        // Count drafts ready
        let draftReady = active.filter { $0.hasDraft }.count
        
        // Top suggestion
        let topSuggestion: String?
        if !overdue.isEmpty {
            let first = overdue[0]
            if first.hasDraft {
                topSuggestion = "Your draft for '\(first.content)' is ready — want to send it? 📧"
            } else if first.actionType == .call {
                topSuggestion = "Want me to look up the number for '\(first.content)'? 📞"
            } else {
                topSuggestion = "'\(first.content)' has been waiting \(first.ageInDays) days. Tackle it first? 💪"
            }
        } else if !stale.isEmpty {
            let first = stale[0]
            topSuggestion = "'\(first.content)' is \(first.ageInDays) days old. Should we break it down or drop it guilt-free? 🐧"
        } else if totalActive > 0 {
            let first = active[0]
            if first.hasDraft {
                topSuggestion = "I already drafted something for '\(first.content)' — ready to review? ✨"
            } else {
                topSuggestion = "Let's start with '\(first.content)' — it's at the top! 🐧"
            }
        } else {
            topSuggestion = nil
        }
        
        // Insight line
        let insightLine: String?
        if draftReady > 0 {
            insightLine = "📝 \(draftReady) draft\(draftReady == 1 ? " is" : "s are") ready to send"
        } else if doneCount >= 3 {
            insightLine = "🔥 You're on fire — \(doneCount) tasks done already!"
        } else {
            insightLine = nil
        }
        
        return NudgyBriefing(
            greeting: greeting,
            taskSummary: taskSummary,
            topSuggestion: topSuggestion,
            draftReadyCount: draftReady,
            overdueItems: Array(overdueItems),
            staleItems: Array(staleItems),
            todayItems: Array(today),
            insightLine: insightLine
        )
    }
    
    // MARK: - Stale Task Intelligence
    
    /// Generate a proactive nudge for a stale task.
    static func staleTaskNudge(for item: NudgeItem) -> String {
        let days = item.ageInDays
        
        if item.hasDraft {
            return "Hey! Your \(item.actionType?.label ?? "task") draft for '\(item.content)' has been ready for \(days) days. Want to send it now? 📧"
        }
        
        if let action = item.actionType {
            switch action {
            case .call:
                return "'\(item.content)' has been sitting for \(days) days. Want me to find the number so you can call right now? 📞"
            case .email:
                return "That email about '\(item.content)' — want me to draft it for you? Been \(days) days 📧"
            case .text:
                return "'\(item.content)' — shall I draft the text message? It's been \(days) days 💬"
            case .search, .navigate, .openLink:
                return "'\(item.content)' — want me to open this up for you? Been \(days) days 🔗"
            case .addToCalendar:
                return "'\(item.content)' — should we schedule this? Been \(days) days 📅"
            }
        }
        
        if days >= 7 {
            return "'\(item.content)' has been here \(days) days. Should we break it down into smaller steps, or drop it guilt-free? No judgment 🐧"
        } else {
            return "'\(item.content)' is \(days) days old. Want to tackle it now, break it down, or snooze it? 🐧"
        }
    }
    
    // MARK: - Evening Review Content
    
    /// Generate evening review data.
    static func generateEveningReview(modelContext: ModelContext) -> (completed: Int, remaining: Int, streak: Int, moodNote: String) {
        let repo = NudgeRepository(modelContext: modelContext)
        let completed = repo.completedTodayCount()
        let remaining = repo.activeCount()
        let streak = RewardService.shared.currentStreak
        
        let moodNote: String
        if completed >= 5 {
            moodNote = "Incredible day! You crushed it 🐟🐟🐟"
        } else if completed >= 3 {
            moodNote = "Solid work today! Every task counts 💙"
        } else if completed >= 1 {
            moodNote = "You showed up and that matters 🐧"
        } else {
            moodNote = "Tomorrow's a fresh start. Rest up 💤"
        }
        
        return (completed, remaining, streak, moodNote)
    }
}
