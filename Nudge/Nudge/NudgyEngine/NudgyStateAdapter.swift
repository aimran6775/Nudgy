//
//  NudgyStateAdapter.swift
//  Nudge
//
//  Phase 15: Bridge between NudgyEngine and PenguinState.
//  Translates NudgyEngine events into PenguinState mutations.
//  This is the integration layer — views observe PenguinState,
//  NudgyEngine drives behavior through this adapter.
//

import Foundation
import SwiftData

// MARK: - NudgyStateAdapter

/// Bridges NudgyEngine to PenguinState for view reactivity.
@MainActor
final class NudgyStateAdapter {
    
    static let shared = NudgyStateAdapter()
    
    private weak var penguinState: PenguinState?
    
    /// Expose connected state for NudgyEngine facade access.
    var connectedState: PenguinState? { penguinState }
    
    private init() {}
    
    /// Connect to the PenguinState instance (call once at app launch).
    func connect(to state: PenguinState) {
        self.penguinState = state
    }
    
    // MARK: - Conversation Flow
    
    /// Send a chat message through NudgyEngine, updating PenguinState along the way.
    func sendChat(_ text: String, modelContext: ModelContext) {
        guard let state = penguinState else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message to PenguinState's display
        state.addUserMessage(text)
        state.isChatGenerating = true
        state.expression = .thinking
        state.streamingText = ""
        
        Task {
            print("🧠 StateAdapter: Sending to LLM: '\(text.prefix(80))'")
            
            let response = await NudgyConversationManager.shared.sendStreaming(
                text,
                modelContext: modelContext
            ) { [weak state] partial in
                state?.streamingText = partial
            }
            
            guard let state = self.penguinState else {
                print("🧠 StateAdapter: penguinState is nil after LLM call!")
                return
            }
            
            // Finalize response
            let responseText = response.text.isEmpty ? state.streamingText : response.text
            print("🧠 StateAdapter: Got response (\(responseText.count) chars): '\(responseText.prefix(100))'")
            
            if !responseText.isEmpty {
                state.addNudgyMessage(responseText)
                
                // Set expression based on content
                state.expression = NudgyEmotionMapper.expressionForResponse(responseText)
                
                // Show as speech bubble
                let wordCount = responseText.split(separator: " ").count
                let readTime = max(4.0, min(10.0, Double(wordCount) * 0.4))
                state.say(responseText, style: .speech, autoDismiss: readTime)
                
                // Speak aloud
                print("🧠 StateAdapter: Speaking response aloud")
                NudgyVoiceOutput.shared.speak(responseText)
                
                // Process side effects
                for effect in response.sideEffects {
                    switch effect {
                    case .taskCreated(let content):
                        state.addSystemMessage("📝 Added: \(content)")
                    case .taskCompleted(let content):
                        state.addSystemMessage("✅ Done: \(content)")
                    case .taskSnoozed(let content):
                        state.addSystemMessage("💤 Snoozed: \(content)")
                    case .memoryLearned(let fact, _):
                        #if DEBUG
                        print("🧠 Learned: \(fact)")
                        #endif
                    }
                }
            }
            
            state.isChatGenerating = false
            
            // Return to idle after response is read
            try? await Task.sleep(for: .seconds(5.0))
            if state.interactionMode == .chatting {
                state.expression = .idle
            }
        }
    }
    
    // MARK: - Greeting
    
    /// Show a smart greeting through PenguinState.
    func greet(userName: String?, activeTaskCount: Int, overdueCount: Int = 0, staleCount: Int = 0, doneToday: Int = 0) {
        guard let state = penguinState else { return }
        
        state.interactionMode = .greeting
        state.expression = .waving
        
        let instant = NudgyReactionEngine.shared.greeting(
            userName: userName,
            activeTaskCount: activeTaskCount
        ) { [weak state] upgraded in
            guard let state, state.interactionMode == .greeting else { return }
            state.say(upgraded, style: .speech, autoDismiss: 5.0)
            // Stop previous TTS and speak upgraded version
            NudgyVoiceOutput.shared.stop()
            NudgyVoiceOutput.shared.speak(upgraded)
        }
        
        state.say(instant, style: .speech, autoDismiss: 5.0)
        // Speak instant greeting — will be interrupted if upgrade arrives
        NudgyVoiceOutput.shared.speak(instant)
        
        // Settle to idle
        Task {
            try? await Task.sleep(for: .seconds(NudgyConfig.Personality.greetingSettleDelay))
            guard let state = self.penguinState else { return }
            if state.expression == .waving {
                state.expression = .idle
                state.interactionMode = .ambient
            }
        }
        
        // Queue proactive nudges
        if overdueCount > 0 || staleCount > 0 {
            Task {
                try? await Task.sleep(for: .seconds(5))
                guard let state = self.penguinState,
                      state.interactionMode == .ambient else { return }
                self.proactiveNudge(overdueCount: overdueCount, staleCount: staleCount, doneToday: doneToday, activeCount: activeTaskCount)
            }
        }
    }
    
    // MARK: - Reactions
    
    /// React to task completion.
    func reactToCompletion(taskContent: String?, remainingCount: Int) {
        guard let state = penguinState else { return }
        
        state.expression = .happy
        HapticService.shared.swipeDone()
        
        let instant = NudgyReactionEngine.shared.completionReaction(
            taskContent: taskContent,
            remainingCount: remainingCount
        ) { [weak state] upgraded in
            guard let state, state.expression == .happy else { return }
            state.say(upgraded, style: .speech, autoDismiss: 3.0)
        }
        
        state.say(instant, style: .speech, autoDismiss: 2.5)
        
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard let state = self.penguinState else { return }
            if state.expression == .happy {
                state.expression = .idle
            }
        }
    }
    
    /// React to task snooze.
    func reactToSnooze(taskContent: String?) {
        guard let state = penguinState else { return }
        
        state.expression = .thumbsUp
        
        let instant = NudgyReactionEngine.shared.snoozeReaction(
            taskContent: taskContent
        ) { [weak state] upgraded in
            guard let state, state.expression == .thumbsUp else { return }
            state.say(upgraded, style: .whisper, autoDismiss: 2.5)
        }
        
        state.say(instant, style: .whisper, autoDismiss: 2.0)
        
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard let state = self.penguinState else { return }
            if state.expression == .thumbsUp {
                state.expression = .idle
            }
        }
    }
    
    /// React to tap.
    func handleTap() {
        guard let state = penguinState else { return }
        
        state.tapCount += 1
        state.lastInteractionDate = .now
        state.isTouched = true
        
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            self.penguinState?.isTouched = false
        }
        
        state.expression = .happy
        HapticService.shared.prepare()
        
        let currentTapCount = state.tapCount
        let instant = NudgyReactionEngine.shared.tapReaction(
            tapCount: currentTapCount
        ) { [weak state] upgraded in
            guard let state, state.tapCount == currentTapCount else { return }
            state.say(upgraded, autoDismiss: 2.5)
        }
        
        state.say(instant, autoDismiss: 2.0)
        
        // Reset tap count after inactivity
        Task {
            try? await Task.sleep(for: .seconds(10))
            guard let state = self.penguinState else { return }
            if Date().timeIntervalSince(state.lastInteractionDate) >= 9 {
                state.tapCount = 0
            }
        }
    }
    
    // MARK: - Task Presentation
    
    /// Present a task with smart commentary.
    func presentTask(content: String, emoji: String?, position: Int, total: Int, accentColor: any Sendable, isStale: Bool, isOverdue: Bool) {
        guard let state = penguinState else { return }
        
        state.currentTaskContent = content
        state.currentTaskEmoji = emoji
        state.queuePositionText = "\(position) of \(total)"
        state.interactionMode = .presentingTask
        state.expression = .idle
        
        let instant = NudgyReactionEngine.shared.taskPresentation(
            content: content, position: position, total: total,
            isStale: isStale, isOverdue: isOverdue
        ) { [weak state] upgraded in
            guard let state, state.currentTaskContent == content else { return }
            state.say(upgraded, autoDismiss: 4.0)
        }
        
        state.say(instant, autoDismiss: 3.5)
    }
    
    // MARK: - Brain Dump
    
    func startListening() {
        guard let state = penguinState else { return }
        state.interactionMode = .listening
        state.expression = .listening
        state.audioLevel = 0
        state.waveformSamples = Array(repeating: 0, count: 20)
        state.say(NudgyReactionEngine.shared.brainDumpStart(), style: .whisper, autoDismiss: 2.0)
    }
    
    func startProcessing() {
        guard let state = penguinState else { return }
        state.interactionMode = .processing
        state.expression = .thinking
        state.audioLevel = 0
        state.say(NudgyReactionEngine.shared.brainDumpProcessing(), style: .thought, autoDismiss: nil)
    }
    
    func showResults(taskCount: Int) {
        guard let state = penguinState else { return }
        state.interactionMode = .showingResults
        state.expression = .happy
        state.clearDialogue()
        state.say(NudgyReactionEngine.shared.brainDumpComplete(taskCount: taskCount), style: .announcement, autoDismiss: 4.0)
    }
    
    // MARK: - Chat Mode
    
    func startChatting() {
        guard let state = penguinState else { return }
        state.interactionMode = .chatting
        state.expression = .idle
        state.isChatInputActive = true
        state.stopIdleChatTimer()
    }
    
    func exitChat() {
        guard let state = penguinState else { return }
        state.isChatInputActive = false
        state.isChatGenerating = false
        state.streamingText = ""
        state.interactionMode = .ambient
        state.expression = .idle
        NudgyVoiceOutput.shared.stop()
        // Preserve conversation in NudgyConversationManager
    }
    
    func clearChatHistory() {
        guard let state = penguinState else { return }
        state.chatMessages.removeAll()
        state.streamingText = ""
        state.isChatGenerating = false
        NudgyVoiceOutput.shared.stop()
        NudgyConversationManager.shared.clearConversation()
    }
    
    // MARK: - Proactive Nudges
    
    private func proactiveNudge(overdueCount: Int, staleCount: Int, doneToday: Int, activeCount: Int) {
        guard let state = penguinState else { return }
        
        if overdueCount > 0 {
            state.expression = .nudging
            let line = overdueCount == 1
                ? String(localized: "Hey, you have one overdue task. Let's knock it out? 💪")
                : String(localized: "\(overdueCount) tasks are overdue. Want to tackle one together? 💪")
            state.say(line, style: .speech, autoDismiss: 5.0)
        } else if staleCount > 0 {
            state.expression = .thinking
            let line = staleCount == 1
                ? String(localized: "One task has been sitting a while. Want to look at it? 🤔")
                : String(localized: "\(staleCount) tasks haven't been touched in 3+ days. Let's review? 📋")
            state.say(line, style: .whisper, autoDismiss: 5.0)
        }
        
        // Return to idle
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard let state = self.penguinState else { return }
            if state.expression == .nudging || state.expression == .thinking {
                state.expression = .idle
            }
        }
    }
}
