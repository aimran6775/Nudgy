//
//  NudgyDialogueEngine.swift
//  Nudge
//
//  Modular dialogue engine with ADHD-informed strategies.
//  Generates contextual one-liners using NudgyLLMService + curated fallbacks.
//  Integrates NudgyADHDKnowledge for research-backed response shaping.
//  All dialogue flows through here — greetings, reactions, check-ins, support.
//

import Foundation

// MARK: - NudgyDialogueEngine

/// Generates contextual dialogue for Nudgy using OpenAI + curated fallbacks.
/// Enriched with ADHD-aware emotional detection and response strategies.
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
            // Insert name naturally — replace first comma-space or period with name
            if greeting.contains(", ") {
                greeting = greeting.replacingOccurrences(of: ". ", with: ", \(name). ", options: [], range: greeting.range(of: ". "))
            } else {
                greeting = greeting.replacingOccurrences(of: "…", with: ", \(name). …", options: [], range: greeting.range(of: "…"))
            }
        }
        
        // Task context — gentle, not hype
        if activeTaskCount == 0 {
            greeting += " " + String(localized: "Nothing waiting. …That's kind of nice.")
        } else if activeTaskCount == 1 {
            greeting += " " + String(localized: "Just one thing today. Simple.")
        } else if activeTaskCount <= 3 {
            greeting += " " + String(localized: "\(activeTaskCount) things. …One at a time, though.")
        } else {
            greeting += " " + String(localized: "\(activeTaskCount) things waiting. …But just the next one matters.")
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
    
    /// Curated completion acknowledgment (gentle, not hype).
    func curatedCompletionReaction(remainingCount: Int) -> String {
        if remainingCount == 0 {
            return NudgyPersonality.CuratedLines.allDoneCelebrations.randomElement()!
        } else if remainingCount == 1 {
            return String(localized: "One more. …Whenever you're ready 💙")
        }
        return NudgyPersonality.CuratedLines.completionCelebrations.randomElement()!
    }
    
    /// AI-powered completion acknowledgment.
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
    
    /// Curated task presentation (gentle, not hype).
    func curatedTaskPresentation(content: String, position: Int, total: Int, isStale: Bool, isOverdue: Bool) -> String {
        if isOverdue {
            return String(localized: "This one's been waiting. …Whenever you're ready 💙")
        } else if isStale {
            return String(localized: "This has been here a while. …Still need it, or can it go? 🧊")
        } else if position == 1 && total == 1 {
            return String(localized: "Just this one. …Small and doable 🐧")
        } else if position == 1 {
            return String(localized: "Let's start here. …Just this one for now 💙")
        } else {
            return String(localized: "Next one. …One at a time 🐧")
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
            return String(localized: "Hmm, I didn't catch any tasks in there. …Want to try again? 🐧")
        } else if taskCount == 1 {
            return String(localized: "One thing captured. …Nice and focused 💙")
        } else {
            return String(localized: "Got \(taskCount) things sorted. …All organized on the iceberg 🧊")
        }
    }
    
    // MARK: - ADHD-Specific Support (NEW)
    
    /// Emotional check-in — occasionally asks how they're doing (not about tasks).
    func emotionalCheckIn(lastMood: String? = nil, daysSinceLastCheckIn: Int = 0) async -> String {
        guard NudgyConfig.isAvailable else {
            return NudgyPersonality.CuratedLines.emotionalCheckins.randomElement()!
        }
        
        let prompt = NudgyPersonality.emotionalCheckInPrompt(
            lastMood: lastMood,
            daysSinceLastCheckIn: daysSinceLastCheckIn
        )
        
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return NudgyPersonality.CuratedLines.emotionalCheckins.randomElement()!
    }
    
    /// Body doubling start message.
    func bodyDoublingStart(taskContent: String) async -> String {
        guard NudgyConfig.isAvailable else {
            return NudgyADHDKnowledge.BodyDoubling.startMessage(taskContent: taskContent)
        }
        
        let prompt = NudgyPersonality.bodyDoublingPrompt(taskContent: taskContent)
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return NudgyADHDKnowledge.BodyDoubling.startMessage(taskContent: taskContent)
    }
    
    /// Body doubling periodic check-in.
    func bodyDoublingCheckIn(minutesElapsed: Int) -> String? {
        NudgyADHDKnowledge.BodyDoubling.checkInMessage(minutesElapsed: minutesElapsed)
    }
    
    /// Body doubling session end.
    func bodyDoublingEnd(minutesWorked: Int) -> String {
        NudgyADHDKnowledge.BodyDoubling.endMessage(minutesWorked: minutesWorked)
    }
    
    /// Task transition support.
    func transitionSupport(from previousTask: String?, to nextTask: String) async -> String {
        guard NudgyConfig.isAvailable else {
            return NudgyADHDKnowledge.TransitionSupport.transitionMessage(
                from: previousTask, to: nextTask
            )
        }
        
        let prompt = NudgyPersonality.transitionPrompt(fromTask: previousTask, toTask: nextTask)
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return NudgyADHDKnowledge.TransitionSupport.transitionMessage(
            from: previousTask, to: nextTask
        )
    }
    
    /// Paralysis-breaking support for stuck tasks.
    func paralysisSupport(staleTasks: [String]) async -> String {
        guard NudgyConfig.isAvailable, !staleTasks.isEmpty else {
            return NudgyPersonality.CuratedLines.paralysisBreakers.randomElement()!
        }
        
        let prompt = NudgyPersonality.paralysisPrompt(staleTasks: staleTasks)
        if let response = await NudgyConversationManager.shared.generateOneShotResponse(prompt: prompt) {
            return response
        }
        return NudgyPersonality.CuratedLines.paralysisBreakers.randomElement()!
    }
    
    /// Overwhelm support — when user seems to have too much going on.
    func overwhelmSupport() -> String {
        NudgyPersonality.CuratedLines.overwhelmSupport.randomElement()!
    }
    
    /// Hyperfocus check-in — gentle time awareness during long sessions.
    func hyperfocusCheckIn() -> String {
        NudgyPersonality.CuratedLines.hyperfocusCheckins.randomElement()!
    }
    
    /// Emotional support based on detected mood.
    func emotionalResponse(for mood: NudgyADHDKnowledge.EmotionalRegulation.DetectedMood) -> String {
        let strategy = NudgyADHDKnowledge.EmotionalRegulation.strategy(for: mood)
        return strategy.curatedResponse ?? NudgyPersonality.CuratedLines.emotionalSupport.randomElement()!
    }
    
    /// Get micro-step suggestion for a stuck task.
    func microStepSuggestion(taskContent: String) -> String {
        let steps = NudgyADHDKnowledge.ExecutiveFunction.microStepsFor(taskContent: taskContent)
        let step = steps.first ?? "Just look at it. That's a start"
        return "\(step). …That's enough for now 🐧"
    }
    
    /// Gentle time context.
    func timeContext() -> String? {
        NudgyADHDKnowledge.TimeAwareness.gentleTimeContext(for: .now)
    }
    
    /// Streak acknowledgment.
    func streakMessage(days: Int) -> String? {
        NudgyADHDKnowledge.PatternRecognition.streakMessage(consecutiveDaysActive: days)
    }
    
    // MARK: - Error
    
    func errorLine() -> String {
        NudgyPersonality.CuratedLines.errors.randomElement()!
    }
}
