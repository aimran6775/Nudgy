//
//  PenguinState.swift
//  Nudge
//
//  Shared observable state for the penguin character.
//  Injected via `.environment(penguinState)` so every screen can influence
//  and react to the penguin's mood, dialogue, and interaction state.
//
//  The penguin is the central interactive character — not a mascot.
//  Every screen reads from this shared state; actions write to it.
//

import SwiftUI
import SwiftData

// MARK: - Penguin Interaction Mode

/// What the penguin is currently doing / available for.
enum PenguinInteractionMode: Equatable {
    /// Default — ambient idle on the home screen
    case ambient
    /// Actively presenting a task to the user
    case presentingTask
    /// Listening to a brain dump (mic active)
    case listening
    /// Processing a brain dump (AI splitting)
    case processing
    /// Showing results from a brain dump
    case showingResults
    /// Greeting the user (app open / onboarding)
    case greeting
    /// Celebrating (all tasks done)
    case celebrating
    /// Sleeping (no tasks, idle for a while)
    case resting
    /// In a conversational chat with the user
    case chatting
}

// MARK: - Speech Bubble Content

/// What the penguin is "saying" right now.
struct PenguinDialogue: Equatable {
    let text: String
    let style: Style
    let autoDismissAfter: TimeInterval?
    
    enum Style: Equatable {
        case speech       // Normal speech bubble
        case thought      // Thought bubble (dots)
        case announcement // Bold, larger text
        case whisper      // Smaller, muted
    }
    
    init(_ text: String, style: Style = .speech, autoDismiss: TimeInterval? = 4.0) {
        self.text = text
        self.style = style
        self.autoDismissAfter = autoDismiss
    }
}

// MARK: - Chat Message

/// A single message in a conversation between the user and Nudgy.
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date = .now
    
    enum Role: Equatable {
        case user
        case nudgy
        case system  // Inline action confirmations ("Created task: ...")
    }
}

// MARK: - Penguin State (Shared Observable)

@Observable
final class PenguinState {
    
    // MARK: - Expression & Mode
    
    /// The penguin's current facial/body expression
    var expression: PenguinExpression = .idle
    
    /// What mode the penguin is in (determines scene layout)
    var interactionMode: PenguinInteractionMode = .ambient
    
    // MARK: - Dialogue
    
    /// Current speech bubble content (nil = no bubble)
    var currentDialogue: PenguinDialogue?
    
    /// Queue of pending dialogue lines
    private var dialogueQueue: [PenguinDialogue] = []
    
    /// Timer for auto-dismissing dialogue
    private var dialogueDismissTask: Task<Void, Never>?
    
    // MARK: - Audio Reactivity
    
    /// Current mic audio level (0.0–1.0), drives body animation
    var audioLevel: Float = 0.0
    
    /// Rolling waveform samples for visual feedback
    var waveformSamples: [Float] = Array(repeating: 0, count: 20)
    
    // MARK: - Task Context (what the penguin is presenting)
    
    /// The task currently being shown to the user (if any)
    var currentTaskContent: String?
    
    /// Emoji for the current task
    var currentTaskEmoji: String?
    
    /// Queue position text (e.g., "1 of 5")
    var queuePositionText: String?
    
    /// Accent color for the current context
    var accentColor: Color = DesignTokens.accentActive
    
    // MARK: - Interaction Feedback
    
    /// Whether the penguin is being tapped/interacted with
    var isTouched: Bool = false
    
    /// Number of taps (for easter egg escalation)
    var tapCount: Int = 0
    
    /// Timestamp of last interaction
    var lastInteractionDate: Date = .now
    
    // MARK: - Idle Chatter
    
    /// Timer for periodic idle chatter
    private var idleChatTask: Task<Void, Never>?
    
    /// How many idle chatters have fired this session
    private var idleChatCount: Int = 0
    
    // MARK: - Chat State (Conversational Mode)
    
    /// Chat message history for the current conversation.
    var chatMessages: [ChatMessage] = []
    
    /// Whether the user has the chat input field open.
    var isChatInputActive: Bool = false
    
    /// Whether Nudgy is currently generating a chat response.
    var isChatGenerating: Bool = false
    
    /// The current partial (streaming) response text.
    var streamingText: String = ""
    
    /// Whether voice conversation mode is active (auto-listen → speak → auto-listen loop)
    var isVoiceConversationActive: Bool = false
    
    /// In-flight chat generation task (for cancellation on exit).
    private var chatTask: Task<Void, Never>?
    
    // MARK: - Dialogue API
    
    /// Show a speech bubble. Auto-dismisses after the specified duration.
    func say(_ text: String, style: PenguinDialogue.Style = .speech, autoDismiss: TimeInterval? = 4.0) {
        let dialogue = PenguinDialogue(text, style: style, autoDismiss: autoDismiss)
        
        // Cancel any existing auto-dismiss
        dialogueDismissTask?.cancel()
        
        currentDialogue = dialogue
        
        if let duration = autoDismiss {
            dialogueDismissTask = Task {
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                self.dismissDialogue()
            }
        }
    }
    
    /// Queue a line — will show after current dialogue dismisses.
    func queueDialogue(_ text: String, style: PenguinDialogue.Style = .speech, autoDismiss: TimeInterval? = 3.0) {
        dialogueQueue.append(PenguinDialogue(text, style: style, autoDismiss: autoDismiss))
    }
    
    /// Dismiss the current speech bubble and show next queued line if any.
    func dismissDialogue() {
        dialogueDismissTask?.cancel()
        
        if let next = dialogueQueue.first {
            dialogueQueue.removeFirst()
            say(next.text, style: next.style, autoDismiss: next.autoDismissAfter)
        } else {
            currentDialogue = nil
        }
    }
    
    /// Clear all dialogue (current + queued).
    func clearDialogue() {
        dialogueDismissTask?.cancel()
        currentDialogue = nil
        dialogueQueue.removeAll()
    }
    
    // MARK: - State Transitions
    
    /// Transition to presenting a task — penguin shows the card.
    func presentTask(content: String, emoji: String?, position: Int, total: Int, accentColor: Color) {
        self.currentTaskContent = content
        self.currentTaskEmoji = emoji
        self.queuePositionText = "\(position) of \(total)"
        self.accentColor = accentColor
        self.interactionMode = .presentingTask
        self.expression = .idle
        startIdleChatTimer()
    }
    
    /// Transition to "all clear" — no tasks left.
    func showAllClear(doneCount: Int) {
        self.currentTaskContent = nil
        self.currentTaskEmoji = nil
        self.queuePositionText = nil
        self.accentColor = DesignTokens.accentComplete
        self.interactionMode = .celebrating
        self.expression = .celebrating
        
        if doneCount > 0 {
            say(
                String(localized: "\(doneCount) done today. Go enjoy something! 🎉"),
                style: .announcement,
                autoDismiss: 6.0
            )
        } else {
            say(
                String(localized: "Nothing on your plate.\nTap me to brain dump!"),
                style: .speech,
                autoDismiss: nil // Stays until user acts
            )
        }
        startIdleChatTimer()
    }
    
    /// Transition to resting — empty state after celebration fades.
    func rest() {
        self.interactionMode = .resting
        self.expression = .sleeping
        self.accentColor = DesignTokens.accentComplete
        clearDialogue()
        stopIdleChatTimer()
    }
    
    /// Transition to listening mode — brain dump recording.
    func startListening() {
        self.interactionMode = .listening
        self.expression = .listening
        self.audioLevel = 0
        self.waveformSamples = Array(repeating: 0, count: 20)
        stopIdleChatTimer()
        say(
            NudgyReactionEngine.shared.brainDumpStart(),
            style: .whisper,
            autoDismiss: 2.0
        )
    }
    
    /// Transition to processing — AI splitting tasks.
    func startProcessing() {
        self.interactionMode = .processing
        self.expression = .thinking
        self.audioLevel = 0
        stopIdleChatTimer()
        say(
            NudgyReactionEngine.shared.brainDumpProcessing(),
            style: .thought,
            autoDismiss: nil
        )
    }
    
    /// Transition to showing brain dump results.
    func showResults(taskCount: Int) {
        self.interactionMode = .showingResults
        self.expression = .happy
        clearDialogue()
        let line = NudgyReactionEngine.shared.brainDumpComplete(taskCount: taskCount)
        say(line, style: .announcement, autoDismiss: 4.0)
    }
    
    /// Reset penguin state when leaving brain dump.
    func exitBrainDump() {
        self.audioLevel = 0
        self.waveformSamples = Array(repeating: 0, count: 20)
        // Don't change expression/mode — OneThingView will set these on appear
    }
    
    // MARK: - Smart Reactions (AI-powered)
    
    /// React to a task being completed — delegates to NudgyEngine.
    func reactToCompletion(taskContent: String? = nil, remainingCount: Int = 0) {
        NudgyEngine.shared.reactToCompletion(taskContent: taskContent, remainingCount: remainingCount)
    }
    
    /// React to a task being snoozed — delegates to NudgyEngine.
    func reactToSnooze(taskContent: String? = nil) {
        NudgyEngine.shared.reactToSnooze(taskContent: taskContent)
    }
    
    /// React to being tapped (easter egg / interactivity) — delegates to NudgyEngine.
    func handleTap() {
        NudgyEngine.shared.handleTap()
    }
    
    // MARK: - Smart Greeting
    
    /// Greet the user — delegates to NudgyEngine.
    func smartGreet(userName: String?, activeTaskCount: Int, overdueCount: Int = 0, staleCount: Int = 0, doneToday: Int = 0) {
        NudgyEngine.shared.greet(
            userName: userName,
            activeTaskCount: activeTaskCount,
            overdueCount: overdueCount,
            staleCount: staleCount,
            doneToday: doneToday
        )
    }
    
    // MARK: - Proactive Nudges (delegated to NudgyEngine via greet())
    // Proactive nudges are now handled by NudgyStateAdapter.greet()
    
    /// Smart task presentation — delegates to NudgyEngine.
    func smartPresentTask(content: String, position: Int, total: Int, isStale: Bool, isOverdue: Bool) {
        NudgyEngine.shared.presentTask(
            content: content, emoji: currentTaskEmoji,
            position: position, total: total,
            accentColor: accentColor,
            isStale: isStale, isOverdue: isOverdue
        )
    }
    
    // MARK: - Idle Chatter Timer
    
    /// Start periodic idle chatter — penguin says something every 30–60 seconds.
    func startIdleChatTimer() {
        stopIdleChatTimer()
        idleChatCount = 0
        
        idleChatTask = Task {
            // Initial delay before first idle chatter
            try? await Task.sleep(for: .seconds(Double.random(in: 25...40)))
            
            while !Task.isCancelled {
                guard self.currentDialogue == nil else {
                    // Wait for current dialogue to finish
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }
                
                // Don't chatter if in non-ambient modes
                guard self.interactionMode == .presentingTask ||
                      self.interactionMode == .ambient ||
                      self.interactionMode == .celebrating else {
                    try? await Task.sleep(for: .seconds(10))
                    continue
                }
                
                // Max 3 idle chatters per session to avoid annoyance
                guard self.idleChatCount < 3 else {
                    break
                }
                
                self.idleChatCount += 1
                
                // Use NudgyEngine's dialogue engine for contextual chatter
                let line = await NudgyDialogueEngine.shared.smartIdleChatter(
                    currentTask: self.currentTaskContent,
                    activeCount: self.queuePositionText != nil ? 1 : 0
                )
                
                if !Task.isCancelled && self.currentDialogue == nil {
                    self.expression = .nudging
                    self.say(line, style: .whisper, autoDismiss: 4.0)
                    
                    // Return to idle expression after
                    try? await Task.sleep(for: .seconds(2))
                    if self.expression == .nudging {
                        self.expression = .idle
                    }
                }
                
                // Random delay before next chatter (45–90 seconds)
                try? await Task.sleep(for: .seconds(Double.random(in: 45...90)))
            }
        }
    }
    
    /// Stop idle chatter.
    func stopIdleChatTimer() {
        idleChatTask?.cancel()
        idleChatTask = nil
    }
    
    // MARK: - Conversational Chat
    
    /// Enter chat mode — penguin becomes conversational.
    /// Does NOT show a chatbot-style welcome message.
    /// The penguin is already greeting via speech bubble on appear.
    func startChatting() {
        interactionMode = .chatting
        expression = .idle
        isChatInputActive = true
        stopIdleChatTimer()
    }
    
    /// Add a user message to the chat.
    func addUserMessage(_ text: String) {
        let message = ChatMessage(role: .user, text: text)
        chatMessages.append(message)
    }
    
    /// Add Nudgy's response to the chat.
    func addNudgyMessage(_ text: String) {
        let message = ChatMessage(role: .nudgy, text: text)
        chatMessages.append(message)
        streamingText = ""
    }
    
    /// Add a system confirmation message to the chat.
    func addSystemMessage(_ text: String) {
        let message = ChatMessage(role: .system, text: text)
        chatMessages.append(message)
    }
    
    /// Send a chat message to Nudgy — delegates to NudgyEngine.
    func sendChat(_ text: String, modelContext: ModelContext) {
        NudgyEngine.shared.chat(text, modelContext: modelContext)
    }
    
    /// Send a chat message with streaming response — delegates to NudgyEngine.
    func sendChatStreaming(_ text: String, modelContext: ModelContext) {
        NudgyEngine.shared.chat(text, modelContext: modelContext)
    }
    
    /// Detect emotional tone from response text and return matching expression.
    private func expressionForResponse(_ text: String) -> PenguinExpression {
        NudgyEmotionMapper.expressionForResponse(text)
    }
    
    /// Exit chat mode — delegates to NudgyEngine.
    /// Preserves both chat messages AND AI session memory.
    func exitChat() {
        NudgyEngine.shared.exitChat()
    }
    
    /// Clear all chat history — delegates to NudgyEngine.
    func clearChatHistory() {
        NudgyEngine.shared.clearChat()
    }
    
    // MARK: - Audio Feed
    
    /// Feed audio level from SpeechService (called during recording).
    func updateAudioLevel(_ level: Float, samples: [Float]) {
        self.audioLevel = level
        self.waveformSamples = samples
        
        // Make penguin react to loud audio bursts
        if level > 0.6 && expression == .listening {
            expression = .talking  // Penguin "reacts" to loud input
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                if self.interactionMode == .listening {
                    self.expression = .listening
                }
            }
        }
    }
    
    /// Reset audio state.
    func resetAudio() {
        self.audioLevel = 0
        self.waveformSamples = Array(repeating: 0, count: 20)
    }
}
