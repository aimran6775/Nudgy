//
//  NudgyToolDefinitions.swift
//  Nudge
//
//  Phase 6: OpenAI function-calling tool schemas.
//  Defines the tools Nudgy can use during conversation as OpenAI
//  function definitions. Pure data — no execution logic.
//

import Foundation

// MARK: - Tool Definitions for OpenAI Function Calling

enum NudgyToolDefinitions {
    
    /// All tools available during conversation.
    static var allTools: [[String: Any]] {
        [lookupTasks, getTaskStats, getCurrentTime, taskAction, extractMemory]
    }
    
    /// Tools for brain dump mode — focused on task creation + memory.
    /// Excludes lookup/stats to bias the LLM toward creating, not querying.
    static var brainDumpTools: [[String: Any]] {
        [taskAction, extractMemory]
    }
    
    /// Read-only tools (no mutations).
    static var readOnlyTools: [[String: Any]] {
        [lookupTasks, getTaskStats, getCurrentTime]
    }
    
    // MARK: - lookup_tasks
    
    static let lookupTasks: [String: Any] = [
        "type": "function",
        "function": [
            "name": "lookup_tasks",
            "description": "Search the user's tasks by status (active, snoozed, done) or by keyword. Use this whenever the user asks about their tasks.",
            "parameters": [
                "type": "object",
                "properties": [
                    "status": [
                        "type": "string",
                        "enum": ["active", "snoozed", "done", "all"],
                        "description": "Filter tasks by status. 'active' for current tasks, 'done' for completed, 'all' for everything."
                    ],
                    "keyword": [
                        "type": "string",
                        "description": "Optional keyword to search in task content. Leave empty for no filter."
                    ]
                ],
                "required": ["status"]
            ] as [String: Any]
        ] as [String: Any]
    ]
    
    // MARK: - get_task_stats
    
    static let getTaskStats: [String: Any] = [
        "type": "function",
        "function": [
            "name": "get_task_stats",
            "description": "Get statistics about the user's tasks: counts by status, overdue count, streak info, and progress.",
            "parameters": [
                "type": "object",
                "properties": [
                    "detail": [
                        "type": "string",
                        "enum": ["summary", "detailed"],
                        "description": "Level of detail. 'summary' for quick overview."
                    ]
                ],
                "required": ["detail"]
            ] as [String: Any]
        ] as [String: Any]
    ]
    
    // MARK: - get_current_time
    
    static let getCurrentTime: [String: Any] = [
        "type": "function",
        "function": [
            "name": "get_current_time",
            "description": "Get the current date, time, and day of the week for time-aware responses.",
            "parameters": [
                "type": "object",
                "properties": [:] as [String: Any],
                "required": [] as [String]
            ] as [String: Any]
        ] as [String: Any]
    ]
    
    // MARK: - task_action
    
    static let taskAction: [String: Any] = [
        "type": "function",
        "function": [
            "name": "task_action",
            "description": "Perform an action on tasks: 'complete' to mark done, 'snooze' to snooze until later, 'create' to add a new task. When creating, always infer emoji, priority, and due date from context.",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": [
                        "type": "string",
                        "enum": ["complete", "snooze", "create"],
                        "description": "The action to perform."
                    ],
                    "task_content": [
                        "type": "string",
                        "description": "For complete/snooze: keyword to match existing task. For create: short, actionable task text (max 8 words)."
                    ],
                    "emoji": [
                        "type": "string",
                        "description": "For create: a single emoji that represents the task. e.g. 📞 for calls, 📧 for emails, 🏋️ for exercise."
                    ],
                    "priority": [
                        "type": "string",
                        "enum": ["high", "medium", "low"],
                        "description": "For create: task priority. 'high' for urgent/ASAP, 'low' for someday/maybe, 'medium' otherwise."
                    ],
                    "due_date": [
                        "type": "string",
                        "description": "For create: due date as YYYY-MM-DD or relative expression like 'tomorrow', 'this weekend', 'next week'. Empty if no deadline mentioned."
                    ],
                    "action_type": [
                        "type": "string",
                        "enum": ["CALL", "TEXT", "EMAIL", ""],
                        "description": "For create: if the task involves contacting someone, specify the action type."
                    ],
                    "contact_name": [
                        "type": "string",
                        "description": "For create: the person's name if the task involves contacting someone."
                    ]
                ],
                "required": ["action", "task_content"]
            ] as [String: Any]
        ] as [String: Any]
    ]
    
    // MARK: - extract_memory
    
    static let extractMemory: [String: Any] = [
        "type": "function",
        "function": [
            "name": "extract_memory",
            "description": "Save a fact you learned about the user for future reference. Use when they share personal details, preferences, or life events.",
            "parameters": [
                "type": "object",
                "properties": [
                    "fact": [
                        "type": "string",
                        "description": "The fact to remember about the user."
                    ],
                    "category": [
                        "type": "string",
                        "enum": ["preference", "personal", "emotional", "behavioral", "contextual"],
                        "description": "Category of the fact."
                    ]
                ],
                "required": ["fact", "category"]
            ] as [String: Any]
        ] as [String: Any]
    ]
}
