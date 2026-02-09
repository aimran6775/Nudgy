//
//  NudgyReactionEngine.swift
//  Nudge
//
//  Phase 13: Smart reactions to user actions.
//  Handles completion celebrations, snooze reassurance, tap Easter eggs,
//  and greeting flows. Uses the two-tier pattern: curated instant + AI upgrade.
//

import Foundation

// MARK: - NudgyReactionEngine

/// Coordinates Nudgy's reactions to user actions.
/// Uses the two-tier pattern: show curated instantly, upgrade with AI async.
@MainActor
final class NudgyReactionEngine {
    
    static let shared = NudgyReactionEngine()
    private let dialogue = NudgyDialogueEngine.shared
    
    private init() {}
    
    // MARK: - Completion Reaction
    
    /// React to a task being completed. Returns (instant, asyncUpgrade).
    func completionReaction(
        taskContent: String?,
        remainingCount: Int,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        let instant = dialogue.curatedCompletionReaction(remainingCount: remainingCount)
        
        // Fire AI upgrade in background
        if let content = taskContent, NudgyConfig.isAvailable {
            Task {
                let smart = await dialogue.smartCompletionReaction(
                    taskContent: content,
                    remainingCount: remainingCount
                )
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Snooze Reaction
    
    /// React to a task being snoozed. Returns (instant, asyncUpgrade).
    func snoozeReaction(
        taskContent: String?,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        let instant = dialogue.curatedSnoozeReaction()
        
        if let content = taskContent, NudgyConfig.isAvailable {
            Task {
                let smart = await dialogue.smartSnoozeReaction(taskContent: content)
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Tap Reaction
    
    /// React to being tapped. Returns (instant, asyncUpgrade).
    func tapReaction(
        tapCount: Int,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        let instant = dialogue.curatedTapReaction(tapCount: tapCount)
        
        if NudgyConfig.isAvailable {
            let count = tapCount
            Task {
                let smart = await dialogue.smartTapReaction(tapCount: count)
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Greeting Flow
    
    /// Show a smart greeting. Returns (instant, asyncUpgrade).
    func greeting(
        userName: String?,
        activeTaskCount: Int,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        // Check memory for user name
        let name = userName ?? NudgyMemory.shared.userName
        let instant = dialogue.curatedGreeting(userName: name, activeTaskCount: activeTaskCount)
        
        if NudgyConfig.isAvailable {
            Task {
                let smart = await dialogue.smartGreeting(
                    userName: name,
                    activeTaskCount: activeTaskCount
                )
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Task Presentation
    
    /// Present a task with two-tier dialogue.
    func taskPresentation(
        content: String,
        position: Int,
        total: Int,
        isStale: Bool,
        isOverdue: Bool,
        onUpgrade: @escaping @MainActor (String) -> Void
    ) -> String {
        let instant = dialogue.curatedTaskPresentation(
            content: content, position: position, total: total,
            isStale: isStale, isOverdue: isOverdue
        )
        
        if NudgyConfig.isAvailable {
            Task {
                let smart = await dialogue.smartTaskPresentation(
                    content: content, position: position, total: total,
                    isStale: isStale, isOverdue: isOverdue
                )
                if smart != instant {
                    onUpgrade(smart)
                }
            }
        }
        
        return instant
    }
    
    // MARK: - Idle Chatter
    
    /// Generate idle chatter (async only, no instant version).
    func idleChatter(currentTask: String?, activeCount: Int) async -> String {
        await dialogue.smartIdleChatter(currentTask: currentTask, activeCount: activeCount)
    }
    
    // MARK: - Brain Dump
    
    func brainDumpStart() -> String { dialogue.brainDumpStart() }
    func brainDumpProcessing() -> String { dialogue.brainDumpProcessing() }
    func brainDumpComplete(taskCount: Int) -> String { dialogue.brainDumpComplete(taskCount: taskCount) }
}
