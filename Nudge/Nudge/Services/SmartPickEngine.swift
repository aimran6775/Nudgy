//
//  SmartPickEngine.swift
//  Nudge
//
//  Intelligent task selection that considers time of day, energy level,
//  task duration, deadlines, and staleness. Replaces random "Pick For Me".
//
//  Scoring formula:
//    score = overdue_bonus + due_today_bonus + stale_penalty
//          + time_match_bonus + energy_match_bonus + quick_win_bonus
//

import SwiftData
import SwiftUI

@MainActor
enum SmartPickEngine {
    
    /// Pick the best task to work on right now, considering context.
    /// Falls back to random if scoring yields ties.
    static func pickBest(
        from items: [NudgeItem],
        currentEnergy: EnergyLevel? = nil
    ) -> NudgeItem? {
        guard !items.isEmpty else { return nil }
        guard items.count > 1 else { return items.first }
        
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        var scored: [(item: NudgeItem, score: Double)] = items.map { item in
            var score: Double = 0
            
            // 1. Overdue bonus (highest priority)
            if let due = item.dueDate, due < now {
                let hoursOverdue = now.timeIntervalSince(due) / 3600
                score += min(30 + hoursOverdue, 50) // cap at 50
            }
            
            // 2. Due today bonus
            if let due = item.dueDate, calendar.isDateInToday(due) {
                score += 20
            }
            
            // 3. Staleness penalty — old items need attention
            if item.ageInDays >= 5 {
                score += Double(item.ageInDays) * 2  // 2 points per day old
            } else if item.ageInDays >= 3 {
                score += Double(item.ageInDays) * 1.5
            }
            
            // 4. Time-of-day matching (if item has scheduled time)
            if let scheduled = item.scheduledTime {
                let scheduledHour = calendar.component(.hour, from: scheduled)
                let hourDiff = abs(hour - scheduledHour)
                if hourDiff <= 1 {
                    score += 15 // Within the hour window
                } else if hourDiff <= 2 {
                    score += 8
                }
            }
            
            // 5. Energy matching
            if let energy = currentEnergy, let itemEnergy = item.energyLevel {
                if energy == itemEnergy {
                    score += 10 // Perfect match
                } else if energy == .low && itemEnergy == .low {
                    score += 12 // Extra boost for easy tasks when tired
                }
            } else if currentEnergy == .low {
                // When tired, prefer short tasks
                if let mins = item.estimatedMinutes, mins <= 10 {
                    score += 8
                }
            }
            
            // 6. Quick win bonus — short tasks get a bump in afternoon
            if let mins = item.estimatedMinutes, mins <= 10 && hour >= 14 {
                score += 5
            }
            
            // 7. Has action/draft ready = lower friction
            if item.hasAction {
                score += 3
            }
            if item.hasDraft {
                score += 4
            }
            
            // 8. Small random jitter to break ties (0–2 points)
            score += Double.random(in: 0...2)
            
            return (item, score)
        }
        
        // Sort by score descending
        scored.sort { $0.score > $1.score }
        
        return scored.first?.item
    }
    
    /// Generate a short explanation of why this task was picked — Nudgy's gentle voice.
    static func reason(for item: NudgeItem) -> String {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        
        if let due = item.dueDate, due < now {
            return String(localized: "this one’s been waiting. …whenever you’re ready 💙")
        }
        
        if let due = item.dueDate, calendar.isDateInToday(due) {
            return String(localized: "due today. …just this one for now 🐧")
        }
        
        if item.ageInDays >= 5 {
            return String(localized: "been sitting \(item.ageInDays) days. …maybe today’s the day? 🧊")
        }
        
        if let mins = item.estimatedMinutes, mins <= 10 {
            return String(localized: "a quick one — \(mins) minutes or less ✨")
        }
        
        if item.hasDraft {
            return String(localized: "draft’s already done. …just needs a send 📬")
        }
        
        if let scheduled = item.scheduledTime {
            let scheduledHour = calendar.component(.hour, from: scheduled)
            if abs(hour - scheduledHour) <= 1 {
                return String(localized: "this was meant for right about now ☕")
            }
        }
        
        return String(localized: "this one feels right. …one thing at a time 🐧")
    }
}
