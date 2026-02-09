    //
//  NudgyEngine.swift
//  Nudge
//
//  Phase 16: Main facade that ties the entire NudgyEngine together.
//  Single entry point for all Nudgy functionality.
//  Views and other services only need to interact with this class.
//
//  Architecture:
//  ┌─────────────────────────────────────────────────┐
//  │                  NudgyEngine                     │
//  │  (facade — single entry point for all Nudgy)    │
//  ├─────────────────────────────────────────────────┤
//  │  NudgyConversationManager  ← orchestrates chat  │
//  │    ├── NudgyLLMService     ← OpenAI API calls   │
//  │    ├── ConversationStore   ← message history     │
//  │    ├── NudgyToolExecutor   ← function calling    │
//  │    └── NudgyToolDefinitions ← tool schemas       │
//  │  NudgyMemory               ← persistent memory   │
//  │  NudgyPersonality          ← identity/prompts    │
//  │  NudgyDialogueEngine       ← one-liner gen      │
//  │  NudgyReactionEngine       ← two-tier reactions  │
//  │  NudgyTaskExtractor        ← task parsing        │
//  │  NudgyVoiceOutput          ← text-to-speech      │
//  │  NudgyEmotionMapper        ← text → expression   │
//  │  NudgyStateAdapter         ← → PenguinState      │
//  │  NudgyConfig               ← all settings        │
//  └─────────────────────────────────────────────────┘
//

import Foundation
import SwiftData

// MARK: - NudgyEngine

/// Main facade for the Nudgy conversational engine.
/// All Nudgy functionality flows through here.
@MainActor @Observable
final class NudgyEngine {
    
    static let shared = NudgyEngine()
    
    // MARK: - Sub-Engines (public for advanced access)
    
    let conversation = NudgyConversationManager.shared
    let memory = NudgyMemory.shared
    let reactions = NudgyReactionEngine.shared
    let dialogue = NudgyDialogueEngine.shared
    let taskExtractor = NudgyTaskExtractor.shared
    let voiceOutput = NudgyVoiceOutput.shared
    let stateAdapter = NudgyStateAdapter.shared
    
    // MARK: - State
    
    /// Whether the engine is fully initialized.
    private(set) var isInitialized = false
    
    /// Whether any LLM backend is available (OpenAI or Apple FM).
    var isAvailable: Bool {
        if NudgyConfig.isAvailable { return true }
        // Also check Apple Foundation Models
        return AIService.shared.isAvailable
    }
    
    /// Whether OpenAI specifically is available.
    var isOpenAIAvailable: Bool { NudgyConfig.isAvailable }
    
    /// Whether any generation is in progress.
    var isGenerating: Bool { conversation.isGenerating }
    
    /// Current streaming text.
    var streamingText: String { conversation.streamingText }
    
    private init() {}
    
    // MARK: - Initialization
    
    /// Bootstrap the engine. Call once at app launch.
    /// Connects to PenguinState and prewarms services.
    func bootstrap(penguinState: PenguinState) {
        guard !isInitialized else { return }
        
        // Connect state adapter
        stateAdapter.connect(to: penguinState)
        
        // Load memory
        _ = memory.store
        
        // Sync user name from AppSettings to memory
        // (will be called again with actual settings)
        
        isInitialized = true
        
        #if DEBUG
        print("🐧 NudgyEngine bootstrapped. LLM available: \(isAvailable)")
        print("🐧 Memory: \(memory.store.facts.count) facts, \(memory.store.conversationSummaries.count) conversations")
        #endif
    }
    
    /// Sync user name from AppSettings to memory.
    func syncUserName(_ name: String?) {
        if let name = name, !name.isEmpty {
            memory.updateUserName(name)
        }
    }
    
    // MARK: - Chat (Primary Interface)
    
    /// Send a chat message. Delegates to state adapter which drives PenguinState.
    func chat(_ text: String, modelContext: ModelContext) {
        stateAdapter.sendChat(text, modelContext: modelContext)
    }
    
    /// Start chat mode.
    func startChat() {
        stateAdapter.startChatting()
    }
    
    /// Exit chat mode (preserves conversation).
    func exitChat() {
        stateAdapter.exitChat()
    }
    
    /// Clear chat history and memory.
    func clearChat() {
        stateAdapter.clearChatHistory()
    }
    
    // MARK: - Greetings
    
    /// Show a smart greeting.
    func greet(userName: String?, activeTaskCount: Int, overdueCount: Int = 0, staleCount: Int = 0, doneToday: Int = 0) {
        syncUserName(userName)
        stateAdapter.greet(
            userName: userName,
            activeTaskCount: activeTaskCount,
            overdueCount: overdueCount,
            staleCount: staleCount,
            doneToday: doneToday
        )
    }
    
    // MARK: - Reactions
    
    /// React to task completion.
    func reactToCompletion(taskContent: String?, remainingCount: Int) {
        stateAdapter.reactToCompletion(taskContent: taskContent, remainingCount: remainingCount)
    }
    
    /// React to task snooze.
    func reactToSnooze(taskContent: String?) {
        stateAdapter.reactToSnooze(taskContent: taskContent)
    }
    
    /// React to tap.
    func handleTap() {
        stateAdapter.handleTap()
    }
    
    // MARK: - Task Presentation
    
    /// Present a task with smart commentary.
    func presentTask(content: String, emoji: String?, position: Int, total: Int, accentColor: any Sendable, isStale: Bool, isOverdue: Bool) {
        stateAdapter.presentTask(
            content: content, emoji: emoji,
            position: position, total: total,
            accentColor: accentColor,
            isStale: isStale, isOverdue: isOverdue
        )
    }
    
    // MARK: - Brain Dump
    
    /// Transition to brain dump listening.
    func startBrainDumpListening() {
        stateAdapter.startListening()
    }
    
    /// Transition to brain dump processing.
    func startBrainDumpProcessing() {
        stateAdapter.startProcessing()
    }
    
    /// Show brain dump results.
    func showBrainDumpResults(taskCount: Int) {
        stateAdapter.showResults(taskCount: taskCount)
    }
    
    /// Split a brain dump transcript into tasks.
    func splitBrainDump(transcript: String) async -> [ExtractedTask] {
        await taskExtractor.splitBrainDump(transcript: transcript)
    }
    
    /// Extract a single task from natural language.
    func extractTask(from input: String) async -> ExtractedTask {
        await taskExtractor.extractTask(from: input)
    }
    
    // MARK: - Voice
    
    // Voice input is handled directly by SpeechService in NudgyHomeView.
    // NudgyEngine manages voice output (TTS) only.
    
    /// Speak text aloud.
    func speak(_ text: String) {
        voiceOutput.speak(text)
    }
    
    /// Stop speaking.
    func stopSpeaking() {
        voiceOutput.stop()
    }
    
    // MARK: - Draft Generation
    
    /// Generate a message draft for a task.
    func generateDraft(taskContent: String, actionType: String, contactName: String?, senderName: String?) async -> (draft: String, subject: String)? {
        await taskExtractor.generateDraft(
            taskContent: taskContent,
            actionType: actionType,
            contactName: contactName,
            senderName: senderName
        )
    }
    
    // MARK: - All Clear / Rest
    
    /// Show all-clear state.
    func showAllClear(doneCount: Int) {
        // Delegate to PenguinState directly via stateAdapter
        // The adapter doesn't have this method, so we go direct
        guard let state = getState() else { return }
        state.showAllClear(doneCount: doneCount)
    }
    
    /// Transition to rest.
    func rest() {
        guard let state = getState() else { return }
        state.rest()
    }
    
    // MARK: - Private
    
    /// Access the connected PenguinState (through adapter).
    func getState() -> PenguinState? {
        stateAdapter.connectedState
    }
}
