//
//  ConversationStore.swift
//  Nudge
//
//  Phase 3: In-memory conversation state with persistence.
//  Manages the active conversation's message history, provides
//  formatted message arrays for the OpenAI API, and handles
//  conversation lifecycle (start, continue, summarize, archive).
//

import Foundation

// MARK: - Conversation Message

/// A single message in the conversation (maps to OpenAI chat format).
struct ConversationMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var toolCalls: [ToolCallRecord]?
    var toolCallId: String?
    
    enum Role: String, Codable {
        case system
        case user
        case assistant
        case tool
    }
    
    init(role: Role, content: String, toolCalls: [ToolCallRecord]? = nil, toolCallId: String? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = .now
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
    
    /// Convert to OpenAI API message format.
    func toAPIDict() -> [String: Any] {
        var dict: [String: Any] = [
            "role": role.rawValue,
            "content": content
        ]
        if let toolCallId = toolCallId {
            dict["tool_call_id"] = toolCallId
        }
        if let toolCalls = toolCalls {
            dict["tool_calls"] = toolCalls.map { $0.toAPIDict() }
        }
        return dict
    }
}

/// Record of a tool call for conversation history.
struct ToolCallRecord: Codable, Equatable {
    let id: String
    let functionName: String
    let arguments: String
    
    func toAPIDict() -> [String: Any] {
        [
            "id": id,
            "type": "function",
            "function": [
                "name": functionName,
                "arguments": arguments
            ]
        ]
    }
}

// MARK: - Conversation Store

/// Manages the active conversation and its message history.
@MainActor @Observable
final class ConversationStore {
    
    // MARK: - State
    
    /// All messages in the current conversation.
    private(set) var messages: [ConversationMessage] = []
    
    /// Number of user turns in this conversation.
    private(set) var turnCount: Int = 0
    
    /// Whether a conversation is active.
    var isActive: Bool { !messages.isEmpty }
    
    /// Tasks created during this conversation (for summary).
    var tasksCreatedCount: Int = 0
    
    /// Tasks completed during this conversation (for summary).
    var tasksCompletedCount: Int = 0
    
    /// The system prompt currently in use.
    private(set) var systemPrompt: String = ""
    
    // MARK: - Conversation Lifecycle
    
    /// Start a new conversation with a system prompt.
    func startConversation(systemPrompt: String) {
        self.messages = [ConversationMessage(role: .system, content: systemPrompt)]
        self.systemPrompt = systemPrompt
        self.turnCount = 0
        self.tasksCreatedCount = 0
        self.tasksCompletedCount = 0
    }
    
    /// Add a user message.
    func addUserMessage(_ content: String) {
        messages.append(ConversationMessage(role: .user, content: content))
        turnCount += 1
    }
    
    /// Add an assistant (Nudgy) message.
    func addAssistantMessage(_ content: String, toolCalls: [ToolCallRecord]? = nil) {
        messages.append(ConversationMessage(role: .assistant, content: content, toolCalls: toolCalls))
    }
    
    /// Add a tool response message.
    func addToolMessage(_ content: String, toolCallId: String) {
        messages.append(ConversationMessage(role: .tool, content: content, toolCallId: toolCallId))
    }
    
    /// Get messages formatted for the OpenAI API.
    /// Trims to context window limit while keeping system prompt and recent messages.
    func apiMessages() -> [[String: Any]] {
        let maxTurns = NudgyConfig.Memory.maxContextTurns
        
        if messages.count <= maxTurns * 2 + 1 {
            // All messages fit
            return messages.map { $0.toAPIDict() }
        }
        
        // Keep system prompt + last N turns
        var result: [[String: Any]] = []
        
        // System prompt always first
        if let system = messages.first, system.role == .system {
            result.append(system.toAPIDict())
        }
        
        // Recent messages (keep tool call chains intact)
        let recentMessages = Array(messages.suffix(maxTurns * 2))
        result.append(contentsOf: recentMessages.map { $0.toAPIDict() })
        
        return result
    }
    
    /// Whether the conversation should be summarized (getting long).
    var needsSummarization: Bool {
        turnCount >= NudgyConfig.Memory.summarizeAfter
    }
    
    /// Generate a summary request prompt for the LLM.
    func summarizationPrompt() -> String {
        let userMessages = messages.filter { $0.role == .user }.map { $0.content }
        let assistantMessages = messages.filter { $0.role == .assistant }.map { $0.content }
        
        return """
        Summarize this conversation in 1-2 sentences. Focus on:
        - What the user wanted help with
        - Key tasks created or completed
        - Any personal details mentioned
        
        User said: \(userMessages.joined(separator: " | "))
        Nudgy said: \(assistantMessages.joined(separator: " | "))
        """
    }
    
    /// Clear the conversation and return a summary for memory.
    func endConversation() -> ConversationSummary? {
        guard turnCount > 0 else { return nil }
        
        // Build a basic summary from messages
        let userTopics = messages
            .filter { $0.role == .user }
            .map { $0.content }
            .prefix(3)
            .joined(separator: "; ")
        
        let summary = ConversationSummary(
            summary: String(userTopics.prefix(200)),
            turnCount: turnCount,
            tasksCreated: tasksCreatedCount,
            tasksCompleted: tasksCompletedCount
        )
        
        // Reset
        messages.removeAll()
        turnCount = 0
        tasksCreatedCount = 0
        tasksCompletedCount = 0
        systemPrompt = ""
        
        return summary
    }
    
    /// Clear without saving summary.
    func clearConversation() {
        messages.removeAll()
        turnCount = 0
        tasksCreatedCount = 0
        tasksCompletedCount = 0
        systemPrompt = ""
    }
    
    /// Get the last N messages for display (excludes system/tool messages).
    func displayMessages(limit: Int = 50) -> [ConversationMessage] {
        messages
            .filter { $0.role == .user || $0.role == .assistant }
            .suffix(limit)
            .map { $0 }
    }
}
