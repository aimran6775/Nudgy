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
    var updatedAt: Date
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
    
    // MARK: Duration & Scheduling
    
    /// Estimated minutes to complete (AI-inferred or user-set)
    var estimatedMinutes: Int?
    
    /// Scheduled start time for timeline view
    var scheduledTime: Date?
    
    /// Actual minutes spent in focus timer (tracked)
    var actualMinutes: Int?
    
    // MARK: Categorization
    
    /// Custom category color hex (user-chosen from palette)
    var categoryColorHex: String?
    
    /// Custom category icon SF Symbol name
    var categoryIcon: String?
    
    // MARK: Routine
    
    /// ID of the routine this task was generated from (nil = ad-hoc task)
    var routineID: UUID?
    
    // MARK: Energy
    
    /// Energy level required: "low", "medium", "high" (for energy-aware scheduling)
    var energyLevelRaw: String?
    
    // MARK: Relationships
    var brainDump: BrainDump?
    
    // MARK: Init
    
    init(
        id: UUID = UUID(),
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
        dueDate: Date? = nil,
        estimatedMinutes: Int? = nil,
        scheduledTime: Date? = nil,
        routineID: UUID? = nil,
        energyLevel: EnergyLevel? = nil,
        categoryColorHex: String? = nil,
        categoryIcon: String? = nil
    ) {
        self.id = id
        self.content = content
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceUrl = sourceUrl
        self.sourcePreview = sourcePreview
        self.statusRaw = ItemStatus.active.rawValue
        self.emoji = emoji
        self.actionTypeRaw = actionType?.rawValue
        self.actionTarget = actionTarget
        self.contactName = contactName
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.sortOrder = sortOrder
        self.priorityRaw = priority?.rawValue
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.scheduledTime = scheduledTime
        self.routineID = routineID
        self.energyLevelRaw = energyLevel?.rawValue
        self.categoryColorHex = categoryColorHex
        self.categoryIcon = categoryIcon
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
        updatedAt = Date()
    }
    
    /// Snooze the item until a specific time
    func snooze(until date: Date) {
        status = .snoozed
        snoozedUntil = date
        updatedAt = Date()
    }
    
    /// Skip (move to end of queue)
    func skip(newOrder: Int) {
        sortOrder = newOrder
        updatedAt = Date()
    }
    
    /// Resurface a snoozed item
    func resurface() {
        status = .active
        snoozedUntil = nil
        updatedAt = Date()
    }
    
    /// Drop (soft delete)
    func drop() {
        status = .dropped
        updatedAt = Date()
    }
    
    // MARK: Computed — Energy Level
    
    var energyLevel: EnergyLevel? {
        get { energyLevelRaw.flatMap { EnergyLevel(rawValue: $0) } }
        set { energyLevelRaw = newValue?.rawValue }
    }
    
    /// Custom category color (if set)
    var categoryColor: Color? {
        categoryColorHex.map { Color(hex: $0) }
    }
    
    /// Formatted duration string (e.g. "15 min")
    var durationLabel: String? {
        guard let mins = estimatedMinutes else { return nil }
        if mins < 60 {
            return "\(mins) min"
        } else {
            let hours = mins / 60
            let remainder = mins % 60
            return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours)h"
        }
    }
    
    /// Whether this task was generated from a routine
    var isFromRoutine: Bool {
        routineID != nil
    }
}

// MARK: - Energy Level

/// Required energy level for a task — used for energy-aware scheduling.
enum EnergyLevel: String, Codable, CaseIterable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"
    
    var label: String {
        switch self {
        case .low:    return String(localized: "Low Energy")
        case .medium: return String(localized: "Medium Energy")
        case .high:   return String(localized: "High Energy")
        }
    }
    
    var icon: String {
        switch self {
        case .low:    return "battery.25percent"
        case .medium: return "battery.50percent"
        case .high:   return "battery.100percent"
        }
    }
    
    /// Recommended time-of-day for this energy level
    var optimalTimeRange: ClosedRange<Int> {
        switch self {
        case .high:   return 9...12   // Morning peak
        case .medium: return 13...17  // Afternoon
        case .low:    return 18...22  // Evening wind-down
        }
    }
}
