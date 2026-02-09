//
//  NudgyDialogueEngine.swift
//  Nudge
//
//  Phase 12: Modular dialogue engine.
//  Replaces PenguinDialogueService with a cleaner architecture.
//  Generates contextual one-liners using NudgyLLMService + curated fallbacks.
//  All dialogue flows through here — greetings, reactions, idle chatter.
//

import Foundation

// MARK: - NudgyDialogueEngine

/// Generates contextual dialogue for Nudgy using OpenAI + curated fallbacks.
@MainActor
final class NudgyDialogueEngine {
    
    static let shared = NudgyDialogueEngine()
    private init() {}
    
    // MARK: - Greeting
    
    /// Curated greeting (instant, no AI).
    func curatedGreeting(userName: String?, activeTaskCount: Int) -> String {
        let name = userName.flatMap { $0.isEmpty ? nil : $0 }
        let hour = Calendar.current.component(.hour, from: .now)
        
        let lines: [String]
        switch hour {
        case 5..<12: lines = NudgyPersonality.CuratedLines.greetingMorning
        case 12..<17: lines = NudgyPersonality.CuratedLines.greetingAfternoon
        case 17..<21: lines = NudgyPersonality.CuratedLines.greetingEvening
        default: lines = NudgyPersonality.CuratedLines.greetingLateNight
        }
        
        var greeting = lines.randomElement()!
        if let name = name {
            greeting = greeting.replacingOccurrences(of: "!", with: ", \(name)!")
        }
        
        if activeTaskCount == 0 {
            greeting += " " + String(localized: "Clean slate! No tasks. Very zen.")
        } else if activeTaskCount == 1 {
            greeting += " " + String(localized: "Just one fish to catch today!")
        } else if activeTaskCount <= 3 {
            greeting += " " + String(localized: "\(activeTaskCount) things lined up. Totally doable!")
        } else {
            greeting += " " + String(localized: "\(activeTaskCount) tasks? One fish at a time.")
        }
        
        return greeting
    }
    
    /// AI-powered greeting (async, replaces curated if fast enough).
    func smartGreeting(userName: String?, activeTaskCount: Int) async -> String {
        guard NudgyConfig.isAvailable else {
            return curatedGreeting(userName: userName, activeTaskCount: activeTaskCount)
        }
        
        let hour = Calendar.current.component(.hour, from: .now)
        let timeOfDay = switch hour {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<21: "evening"
        default: "late night"
        }
        
        let memoryContext = NudgyMemory.shared.memoryContext()
        let prompt = NudgyPersonality.greetingPrompt(
            userName: userName,
            activeTaskCount: activeTaskCount,
            timeOfDay: timeOfDay,
            memoryContext: memoryContext
        )
        
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return curatedGreeting(userName: userName, activeTaskCount: activeTaskCount)
    }
    
    // MARK: - Task Reactions
    
    /// Curated completion celebration.
    func curatedCompletionReaction(remainingCount: Int) -> String {
        if remainingCount == 0 {
            return NudgyPersonality.CuratedLines.allDoneCelebrations.randomElement()!
        } else if remainingCount == 1 {
            return String(localized: "Just one more to go! 💪")
        }
        return NudgyPersonality.CuratedLines.completionCelebrations.randomElement()!
    }
    
    /// AI-powered completion celebration.
    func smartCompletionReaction(taskContent: String, remainingCount: Int) async -> String {
        guard NudgyConfig.isAvailable else {
            return curatedCompletionReaction(remainingCount: remainingCount)
        }
        
        let prompt = NudgyPersonality.completionPrompt(
            taskContent: taskContent,
            remainingCount: remainingCount
        )
        
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return curatedCompletionReaction(remainingCount: remainingCount)
    }
    
    /// Curated snooze reaction.
    func curatedSnoozeReaction() -> String {
        NudgyPersonality.CuratedLines.snoozeReactions.randomElement()!
    }
    
    /// AI-powered snooze reaction.
    func smartSnoozeReaction(taskContent: String) async -> String {
        guard NudgyConfig.isAvailable else {
            return curatedSnoozeReaction()
        }
        
        let prompt = NudgyPersonality.snoozePrompt(taskContent: taskContent)
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return curatedSnoozeReaction()
    }
    
    // MARK: - Tap Reactions (Easter Egg)
    
    /// Curated tap reaction.
    func curatedTapReaction(tapCount: Int) -> String {
        let lines = NudgyPersonality.CuratedLines.tapReactions
        let index = min(tapCount - 1, lines.count - 1)
        return lines[max(0, index)]
    }
    
    /// AI-powered tap reaction.
    func smartTapReaction(tapCount: Int) async -> String {
        guard NudgyConfig.isAvailable else {
            return curatedTapReaction(tapCount: tapCount)
        }
        
        let prompt = NudgyPersonality.tapPrompt(tapCount: tapCount)
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return curatedTapReaction(tapCount: tapCount)
    }
    
    // MARK: - Idle Chatter
    
    /// AI-powered idle chatter.
    func smartIdleChatter(currentTask: String?, activeCount: Int) async -> String {
        guard NudgyConfig.isAvailable else {
            return NudgyPersonality.CuratedLines.idleChatter.randomElement()!
        }
        
        let hour = Calendar.current.component(.hour, from: .now)
        let timeOfDay = switch hour {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<21: "evening"
        default: "late night"
        }
        
        let prompt = NudgyPersonality.idlePrompt(
            currentTask: currentTask,
            activeCount: activeCount,
            timeOfDay: timeOfDay
        )
        
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return NudgyPersonality.CuratedLines.idleChatter.randomElement()!
    }
    
    // MARK: - Task Presentation
    
    /// Curated task presentation.
    func curatedTaskPresentation(content: String, position: Int, total: Int, isStale: Bool, isOverdue: Bool) -> String {
        if isOverdue {
            return String(localized: "Hey! This one needs some love! Let's do it together ⚡")
        } else if isStale {
            return String(localized: "Sooo... this has been chilling here a while 🧊")
        } else if position == 1 && total == 1 {
            return String(localized: "LAST ONE! *bouncing* You're so close! 🏁")
        } else if position == 1 {
            return String(localized: "Ooh, let's start with this one! 🐟")
        } else {
            return String(localized: "Next fish! Keep swimming! 🐟")
        }
    }
    
    /// AI-powered task presentation.
    func smartTaskPresentation(content: String, position: Int, total: Int, isStale: Bool, isOverdue: Bool) async -> String {
        guard NudgyConfig.isAvailable else {
            return curatedTaskPresentation(content: content, position: position, total: total, isStale: isStale, isOverdue: isOverdue)
        }
        
        let prompt = NudgyPersonality.taskPresentationPrompt(
            content: content, position: position, total: total,
            isStale: isStale, isOverdue: isOverdue
        )
        
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return curatedTaskPresentation(content: content, position: position, total: total, isStale: isStale, isOverdue: isOverdue)
    }
    
    // MARK: - Brain Dump Phases
    
    func brainDumpStart() -> String {
        NudgyPersonality.CuratedLines.brainDumpStart.randomElement()!
    }
    
    func brainDumpProcessing() -> String {
        NudgyPersonality.CuratedLines.brainDumpProcessing.randomElement()!
    }
    
    func brainDumpComplete(taskCount: Int) -> String {
        if taskCount == 0 {
            return String(localized: "Hmm, I didn't catch any tasks in there! Try again? 🐧")
        } else if taskCount == 1 {
            return String(localized: "Found one fish! Nice and focused! 🐟")
        } else {
            return String(localized: "*sorts \(taskCount) fish into buckets* All organized! 📋")
        }
    }
    
    // MARK: - Error
    
    func errorLine() -> String {
        NudgyPersonality.CuratedLines.errors.randomElement()!
    }
}
