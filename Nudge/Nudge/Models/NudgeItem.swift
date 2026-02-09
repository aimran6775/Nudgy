//
//  NudgeItem.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftData
import SwiftUI

// MARK: - Enums

/// How the item entered Nudge
enum SourceType: String, Codable, CaseIterable {
    case voiceDump   = "voice"
    case share       = "share"
    case manual      = "manual"
    
    var label: String {
        switch self {
        case .voiceDump: return String(localized: "Voice Dump")
        case .share:     return String(localized: "Shared")
        case .manual:    return String(localized: "Manual")
        }
    }
    
    var icon: String {
        switch self {
        case .voiceDump: return "mic.fill"
        case .share:     return "square.and.arrow.down.fill"
        case .manual:    return "plus.circle.fill"
        }
    }
}

/// Current lifecycle state
enum ItemStatus: String, Codable, CaseIterable {
    case active   = "active"
    case snoozed  = "snoozed"
    case done     = "done"
    case dropped  = "dropped"
}

/// Task priority level inferred from language urgency cues
enum TaskPriority: String, Codable, CaseIterable {
    case high   = "high"
    case medium = "medium"
    case low    = "low"
    
    var icon: String {
        switch self {
        case .high:   return "exclamationmark.triangle.fill"
        case .medium: return "flag.fill"
        case .low:    return "arrow.down.circle"
        }
    }
    
    var label: String {
        switch self {
        case .high:   return String(localized: "High")
        case .medium: return String(localized: "Medium")
        case .low:    return String(localized: "Low")
        }
    }
    
    var sortWeight: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

/// Detected action type from AI or Share Extension
enum ActionType: String, Codable, CaseIterable {
    case call     = "CALL"
    case text     = "TEXT"
    case email    = "EMAIL"
    case openLink = "LINK"
    
    var icon: String {
        switch self {
        case .call:     return "phone.fill"
        case .text:     return "message.fill"
        case .email:    return "envelope.fill"
        case .openLink: return "link"
        }
    }
    
    var label: String {
        switch self {
        case .call:     return String(localized: "Call")
        case .text:     return String(localized: "Text")
        case .email:    return String(localized: "Email")
        case .openLink: return String(localized: "Open Link")
        }
    }
}

// MARK: - NudgeItem Model

@Model
final class NudgeItem {
    
    // MARK: Identity
    var id: UUID
    
    // MARK: Content
    var content: String
    var emoji: String?
    
    // MARK: Source
    var sourceTypeRaw: String
    var sourceUrl: String?
    var sourcePreview: String?
    
    // MARK: Status
    var statusRaw: String
    var snoozedUntil: Date?
    
    // MARK: Scheduling
    var dueDate: Date?
    var priorityRaw: String?
    
    // MARK: Timestamps
    var createdAt: Date
    var completedAt: Date?
    
    // MARK: Ordering
    var sortOrder: Int
    
    // MARK: Action
    var actionTypeRaw: String?
    var actionTarget: String?
    var contactName: String?
    
    // MARK: AI Draft (Pro)
    var aiDraft: String?
    var aiDraftSubject: String?
    var draftGeneratedAt: Date?
    
    // MARK: Relationships
    var brainDump: BrainDump?
    
    // MARK: Init
    
    init(
        content: String,
        sourceType: SourceType = .manual,
        sourceUrl: String? = nil,
        sourcePreview: String? = nil,
        emoji: String? = nil,
        actionType: ActionType? = nil,
        actionTarget: String? = nil,
        contactName: String? = nil,
        sortOrder: Int = 0,
        priority: TaskPriority? = nil,
        dueDate: Date? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceUrl = sourceUrl
        self.sourcePreview = sourcePreview
        self.statusRaw = ItemStatus.active.rawValue
        self.emoji = emoji
        self.actionTypeRaw = actionType?.rawValue
        self.actionTarget = actionTarget
        self.contactName = contactName
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.priorityRaw = priority?.rawValue
        self.dueDate = dueDate
    }
    
    // MARK: Computed — Source Type
    
    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .manual }
        set { sourceTypeRaw = newValue.rawValue }
    }
    
    // MARK: Computed — Status
    
    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    
    // MARK: Computed — Action Type
    
    var actionType: ActionType? {
        get { actionTypeRaw.flatMap { ActionType(rawValue: $0) } }
        set { actionTypeRaw = newValue?.rawValue }
    }
    
    // MARK: Computed — Priority
    
    var priority: TaskPriority? {
        get { priorityRaw.flatMap { TaskPriority(rawValue: $0) } }
        set { priorityRaw = newValue?.rawValue }
    }
    
    /// Whether this task has a due date set
    var hasDueDate: Bool {
        dueDate != nil
    }
    
    /// Whether due date is in the past
    var isPastDue: Bool {
        dueDate?.isPast ?? false
    }
    
    // MARK: Computed — Derived Properties
    
    /// How many days since creation
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
    
    /// Item is stale: active for 3+ days
    var isStale: Bool {
        status == .active && ageInDays >= 3
    }
    
    /// Item is overdue: snoozed and past the snooze time
    var isOverdue: Bool {
        status == .snoozed && (snoozedUntil?.isPast ?? false)
    }
    
    /// Should this item resurface? (snooze expired)
    var shouldResurface: Bool {
        status == .snoozed && (snoozedUntil?.isPast ?? false)
    }
    
    /// Has an action button attached
    var hasAction: Bool {
        actionType != nil
    }
    
    /// Has an AI-generated draft ready
    var hasDraft: Bool {
        aiDraft != nil && !(aiDraft?.isEmpty ?? true)
    }
    
    /// Accent status for the card border color
    var accentStatus: AccentStatus {
        if status == .done { return .complete }
        if isOverdue { return .overdue }
        if isStale { return .stale }
        return .active
    }
    
    // MARK: Actions
    
    /// Mark item as done
    func markDone() {
        status = .done
        completedAt = Date()
    }
    
    /// Snooze the item until a specific time
    func snooze(until date: Date) {
        status = .snoozed
        snoozedUntil = date
    }
    
    /// Skip (move to end of queue)
    func skip(newOrder: Int) {
        sortOrder = newOrder
    }
    
    /// Resurface a snoozed item
    func resurface() {
        status = .active
        snoozedUntil = nil
    }
    
    /// Drop (soft delete)
    func drop() {
        status = .dropped
    }
}
