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
                // Update streaming text AND the speech bubble in real-time
                state?.streamingText = partial
                if !partial.isEmpty {
                    state?.say(partial, style: .speech, autoDismiss: nil)
                }
            }
            
            guard let state = self.penguinState else {
                print("🧠 StateAdapter: penguinState is nil after LLM call!")
                return
            }
            
            // Process side effects FIRST so task feedback appears immediately
            let isBrainDump = NudgyConversationManager.shared.isBrainDumpMode
            var taskCount = 0
            for effect in response.sideEffects {
                switch effect {
                case .taskCreated(let content):
                    taskCount += 1
                    if isBrainDump {
                        state.addSystemMessage("📝 Captured: \(content)")
                    } else {
                        state.addSystemMessage("📝 Added: \(content)")
                    }
                case .taskCompleted(let content):
                    state.addSystemMessage("✅ Done: \(content)")
                case .taskSnoozed(let content):
                    state.addSystemMessage("💤 Snoozed: \(content)")
                case .memoryLearned(let fact, _):
                    #if DEBUG
                    print("🧠 Learned: \(fact)")
                    #endif
                case .actionExecuted(let actionType, let target):
                    let icon = switch actionType {
                    case "CALL": "📞"
                    case "TEXT": "💬"
                    case "EMAIL": "📧"
                    case "SEARCH": "🔍"
                    case "NAVIGATE": "🗺️"
                    default: "⚡"
                    }
                    state.addSystemMessage("\(icon) Executing: \(actionType.lowercased()) → \(target)")
                case .draftGenerated(let type, let recipient, let body, _):
                    let icon = type == "email" ? "📧" : "💬"
                    // Add a rich message with the draft attachment
                    var msg = ChatMessage(role: .nudgy, text: "\(icon) Draft for \(recipient) ready — tap to review")
                    msg.attachment = .draft(DraftAttachment(
                        draftType: type,
                        recipientName: recipient,
                        subject: nil,
                        body: body,
                        contactTarget: nil
                    ))
                    state.chatMessages.append(msg)
                }
            }
            
            // In brain dump mode, show running total
            if isBrainDump && taskCount > 0 {
                let total = NudgyConversationManager.shared.conversationStore.tasksCreatedCount
                state.addSystemMessage("🐧 Total captured: \(total) task\(total == 1 ? "" : "s")")
            }
            
            // Finalize response
            let responseText = response.text.isEmpty ? state.streamingText : response.text
            print("🧠 StateAdapter: Got response (\(responseText.count) chars, \(taskCount) tasks): '\(responseText.prefix(100))'")
            
            if !responseText.isEmpty {
                state.addNudgyMessage(responseText)
                
                // Set expression based on content
                state.expression = NudgyEmotionMapper.expressionForResponse(responseText)
                
                // Show final response as speech bubble
                let wordCount = responseText.split(separator: " ").count
                let readTime = max(3.0, min(8.0, Double(wordCount) * 0.3))
                state.say(responseText, style: .speech, autoDismiss: readTime)
                
                // CRITICAL: Ensure audio session is configured for playback
                NudgyVoiceOutput.shared.prepareForPlayback()
                
                // Speak aloud
                print("🧠 StateAdapter: Speaking response aloud")
                let willSpeak = NudgyVoiceOutput.shared.speak(responseText)
                
                // If TTS was skipped (voice disabled or empty text), post a notification
                // so the voice conversation loop can auto-resume listening without
                // waiting for isSpeaking to transition.
                if !willSpeak && state.isVoiceConversationActive {
                    print("🧠 StateAdapter: TTS skipped, posting ttsSkipped notification")
                    // Brief delay to let UI settle, then notify
                    try? await Task.sleep(for: .milliseconds(300))
                    NotificationCenter.default.post(name: .nudgyTTSSkipped, object: nil)
                }
            }
            
            state.isChatGenerating = false
            
            // Return to idle after response is read (but not during voice conversation — loop handles it)
            if !state.isVoiceConversationActive {
                try? await Task.sleep(for: .seconds(4.0))
                if state.interactionMode == .chatting {
                    state.expression = .idle
                }
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
            NudgyVoiceOutput.shared.speakReaction(upgraded)
        }
        
        state.say(instant, style: .speech, autoDismiss: 2.5)
        NudgyVoiceOutput.shared.speakReaction(instant)
        
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
            NudgyVoiceOutput.shared.speakReaction(upgraded)
        }
        
        state.say(instant, style: .whisper, autoDismiss: 2.0)
        NudgyVoiceOutput.shared.speakReaction(instant)
        
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
    
    // MARK: - Proactive Nudges (Conversational)
    
    /// Proactive nudges now enter chat mode so the user can respond.
    /// They feel like Nudgy initiating a conversation, not a notification.
    private func proactiveNudge(overdueCount: Int, staleCount: Int, doneToday: Int, activeCount: Int) {
        guard let state = penguinState else { return }
        
        let line: String
        if overdueCount > 0 {
            state.expression = .nudging
            line = overdueCount == 1
                ? String(localized: "Hey… one thing is overdue. Want to look at it together? 💙")
                : String(localized: "\(overdueCount) things have been waiting. …Pick the easiest one? 💙")
        } else if staleCount > 0 {
            state.expression = .thinking
            line = staleCount == 1
                ? String(localized: "One thing has been sitting a while. …Still need it? 🧊")
                : String(localized: "\(staleCount) things haven't moved in a few days. …Want to sort through them? 🧊")
        } else {
            return
        }
        
        // Show as a speech bubble AND add to chat history so the user can reply
        state.say(line, style: .speech, autoDismiss: 8.0)
        state.addNudgyMessage(line)
        
        // Transition to chatting mode so the user can respond
        state.interactionMode = .chatting
        state.isChatInputActive = true
        
        // Auto-settle back to ambient if no interaction
        Task {
            try? await Task.sleep(for: .seconds(12))
            guard let state = self.penguinState else { return }
            if state.interactionMode == .chatting && !state.isChatGenerating {
                state.interactionMode = .ambient
                state.isChatInputActive = false
                if state.expression == .nudging || state.expression == .thinking {
                    state.expression = .idle
                }
            }
        }
    }
}
