//
//  NudgyToolExecutor.swift
//  Nudge
//
//  Phase 7: Execute tool calls from the LLM against real data.
//  Bridges between OpenAI function calling and NudgeRepository.
//  Each tool call returns a string result that feeds back to the LLM.
//

import Foundation
import SwiftData

// MARK: - Tool Execution Result

/// Result of executing a tool call.
struct ToolExecutionResult {
    let toolCallId: String
    let result: String
    let sideEffects: [ToolSideEffect]
    
    enum ToolSideEffect {
        case taskCreated(content: String)
        case taskCompleted(content: String)
        case taskSnoozed(content: String)
        case memoryLearned(fact: String, category: String)
    }
}

// MARK: - NudgyToolExecutor

/// Executes tool calls from the LLM against the user's real data.
@MainActor
final class NudgyToolExecutor {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Execute a tool call and return the result string.
    func execute(_ toolCall: LLMToolCall) -> ToolExecutionResult {
        let args = toolCall.parsedArguments() ?? [:]
        
        switch toolCall.functionName {
        case "lookup_tasks":
            return executeLookupTasks(toolCallId: toolCall.id, args: args)
        case "get_task_stats":
            return executeGetTaskStats(toolCallId: toolCall.id, args: args)
        case "get_current_time":
            return executeGetCurrentTime(toolCallId: toolCall.id)
        case "task_action":
            return executeTaskAction(toolCallId: toolCall.id, args: args)
        case "extract_memory":
            return executeExtractMemory(toolCallId: toolCall.id, args: args)
        default:
            return ToolExecutionResult(
                toolCallId: toolCall.id,
                result: "Unknown tool: \(toolCall.functionName)",
                sideEffects: []
            )
        }
    }
    
    /// Execute multiple tool calls.
    func executeAll(_ toolCalls: [LLMToolCall]) -> [ToolExecutionResult] {
        toolCalls.map { execute($0) }
    }
    
    // MARK: - Tool Implementations
    
    private func executeLookupTasks(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let status = args["status"] as? String ?? "active"
        let keyword = args["keyword"] as? String ?? ""
        
        let repo = NudgeRepository(modelContext: modelContext)
        let allItems: [NudgeItem]
        
        switch status {
        case "active":
            allItems = repo.fetchActiveQueue()
        case "snoozed":
            let grouped = repo.fetchAllGrouped()
            allItems = grouped.snoozed
        case "done":
            let grouped = repo.fetchAllGrouped()
            allItems = grouped.doneToday
        default:
            let grouped = repo.fetchAllGrouped()
            allItems = grouped.active + grouped.snoozed + grouped.doneToday
        }
        
        var filtered = allItems
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !kw.isEmpty {
            filtered = filtered.filter { $0.content.lowercased().contains(kw) }
        }
        
        if filtered.isEmpty {
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "No tasks found matching that criteria.",
                sideEffects: []
            )
        }
        
        let lines = filtered.prefix(8).map { item in
            var line = "- \(item.emoji ?? "📝") \(item.content) [\(item.statusRaw)]"
            if item.isOverdue { line += " ⚠️OVERDUE" }
            else if item.isStale { line += " ⏰stale(\(item.ageInDays)d)" }
            if let contact = item.contactName, !contact.isEmpty {
                line += " → \(contact)"
            }
            return line
        }
        
        let total = filtered.count
        var result = "Found \(total) task\(total == 1 ? "" : "s"):\n" + lines.joined(separator: "\n")
        if total > 8 { result += "\n...and \(total - 8) more." }
        
        return ToolExecutionResult(toolCallId: toolCallId, result: result, sideEffects: [])
    }
    
    private func executeGetTaskStats(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let repo = NudgeRepository(modelContext: modelContext)
        let grouped = repo.fetchAllGrouped()
        let active = grouped.active
        let snoozed = grouped.snoozed
        let doneToday = grouped.doneToday
        
        let overdue = active.filter { $0.isOverdue }
        let stale = active.filter { $0.isStale }
        let oldest = active.max(by: { $0.ageInDays < $1.ageInDays })
        
        var lines: [String] = []
        lines.append("Active: \(active.count)")
        lines.append("Snoozed: \(snoozed.count)")
        lines.append("Done today: \(doneToday.count)")
        if !overdue.isEmpty { lines.append("⚠️ Overdue: \(overdue.count)") }
        if !stale.isEmpty { lines.append("⏰ Stale (3+ days): \(stale.count)") }
        if let o = oldest, o.ageInDays > 0 {
            lines.append("Oldest active: \"\(o.content)\" (\(o.ageInDays) days)")
        }
        
        return ToolExecutionResult(
            toolCallId: toolCallId,
            result: lines.joined(separator: "\n"),
            sideEffects: []
        )
    }
    
    private func executeGetCurrentTime(toolCallId: String) -> ToolExecutionResult {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        let hour = Calendar.current.component(.hour, from: now)
        
        let period: String
        switch hour {
        case 5..<12: period = "morning"
        case 12..<17: period = "afternoon"
        case 17..<21: period = "evening"
        default: period = "late night"
        }
        
        return ToolExecutionResult(
            toolCallId: toolCallId,
            result: "\(formatter.string(from: now)). It's \(period).",
            sideEffects: []
        )
    }
    
    private func executeTaskAction(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let action = (args["action"] as? String ?? "").lowercased()
        let taskContent = args["task_content"] as? String ?? ""
        
        let repo = NudgeRepository(modelContext: modelContext)
        
        switch action {
        case "complete":
            let active = repo.fetchActiveQueue()
            if let match = active.first(where: { $0.content.lowercased().contains(taskContent.lowercased()) }) {
                repo.markDone(match)
                HapticService.shared.swipeDone()
                return ToolExecutionResult(
                    toolCallId: toolCallId,
                    result: "Marked '\(match.content)' as done! ✅",
                    sideEffects: [.taskCompleted(content: match.content)]
                )
            }
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "Couldn't find a task matching '\(taskContent)'.",
                sideEffects: []
            )
            
        case "snooze":
            let active = repo.fetchActiveQueue()
            if let match = active.first(where: { $0.content.lowercased().contains(taskContent.lowercased()) }) {
                repo.snooze(match, until: Date.tomorrowMorning)
                return ToolExecutionResult(
                    toolCallId: toolCallId,
                    result: "Snoozed '\(match.content)' until tomorrow. 💤",
                    sideEffects: [.taskSnoozed(content: match.content)]
                )
            }
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "Couldn't find a task matching '\(taskContent)'.",
                sideEffects: []
            )
            
        case "create":
            _ = repo.createManual(content: taskContent)
            HapticService.shared.cardAppear()
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "Created new task: '\(taskContent)' 📝",
                sideEffects: [.taskCreated(content: taskContent)]
            )
            
        default:
            return ToolExecutionResult(
                toolCallId: toolCallId,
                result: "Unknown action '\(action)'. Use 'complete', 'snooze', or 'create'.",
                sideEffects: []
            )
        }
    }
    
    private func executeExtractMemory(toolCallId: String, args: [String: Any]) -> ToolExecutionResult {
        let fact = args["fact"] as? String ?? ""
        let categoryRaw = args["category"] as? String ?? "contextual"
        
        guard !fact.isEmpty else {
            return ToolExecutionResult(toolCallId: toolCallId, result: "No fact provided.", sideEffects: [])
        }
        
        let category: NudgyMemoryFact.FactCategory
        switch categoryRaw {
        case "preference": category = .preference
        case "personal": category = .personal
        case "emotional": category = .emotional
        case "behavioral": category = .behavioral
        default: category = .contextual
        }
        
        NudgyMemory.shared.learn(fact, category: category)
        
        // Check if fact contains a name
        if categoryRaw == "personal" && fact.lowercased().contains("name") {
            // Try to extract the name
            let words = fact.components(separatedBy: " ")
            if let nameIndex = words.firstIndex(where: { $0.lowercased() == "is" || $0.lowercased() == "name" }),
               nameIndex + 1 < words.count {
                let name = words[(nameIndex + 1)...].joined(separator: " ")
                    .trimmingCharacters(in: .punctuationCharacters)
                NudgyMemory.shared.updateUserName(name)
            }
        }
        
        return ToolExecutionResult(
            toolCallId: toolCallId,
            result: "Remembered: \(fact)",
            sideEffects: [.memoryLearned(fact: fact, category: categoryRaw)]
        )
    }
}
