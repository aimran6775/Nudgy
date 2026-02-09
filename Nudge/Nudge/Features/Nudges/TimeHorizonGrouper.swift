//
//  TimeHorizonGrouper.swift
//  Nudge
//
//  Groups NudgeItems into time-based horizons instead of status-based sections.
//  Based on ADHD research: the "now vs not now" model (Barkley, 2012).
//
//  ADHD brains perceive two time categories:
//  • NOW — items that need attention today
//  • NOT NOW — everything else (functionally invisible regardless of importance)
//
//  This grouper maps that into a gentle 5-tier hierarchy:
//  Today → Tomorrow → This Week → Later → Snoozed
//  with "Today" capped at 5 items max to respect working memory limits (~3-4 items, Rapport et al., 2008).
//

import Foundation

// MARK: - Time Horizon

/// The temporal bucket a nudge belongs to.
/// Ordered from most urgent (now) to least urgent (snoozed/done).
enum TimeHorizon: String, CaseIterable, Identifiable {
    case today     = "today"
    case tomorrow  = "tomorrow"
    case thisWeek  = "thisWeek"
    case later     = "later"
    case snoozed   = "snoozed"
    case doneToday = "doneToday"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .today:     return String(localized: "Today")
        case .tomorrow:  return String(localized: "Tomorrow")
        case .thisWeek:  return String(localized: "This Week")
        case .later:     return String(localized: "Later")
        case .snoozed:   return String(localized: "Snoozed")
        case .doneToday: return String(localized: "Done Today")
        }
    }
    
    var icon: String {
        switch self {
        case .today:     return "sun.max.fill"
        case .tomorrow:  return "sunrise.fill"
        case .thisWeek:  return "calendar"
        case .later:     return "tray.fill"
        case .snoozed:   return "clock.fill"
        case .doneToday: return "checkmark.circle.fill"
        }
    }
    
    /// Whether this section should be expanded by default.
    var defaultExpanded: Bool {
        switch self {
        case .today:     return true
        case .tomorrow:  return true
        case .thisWeek:  return false
        case .later:     return false
        case .snoozed:   return false
        case .doneToday: return false
        }
    }
}

// MARK: - Grouped Result

/// The output of the time-horizon grouping operation.
struct TimeHorizonGroups {
    var today: [NudgeItem] = []
    var tomorrow: [NudgeItem] = []
    var thisWeek: [NudgeItem] = []
    var later: [NudgeItem] = []
    var snoozed: [NudgeItem] = []
    var doneToday: [NudgeItem] = []
    
    /// All active items across all horizons (for Live Activity, counts, etc.)
    var allActive: [NudgeItem] {
        today + tomorrow + thisWeek + later
    }
    
    /// Total active count
    var activeCount: Int {
        allActive.count
    }
    
    /// Whether there's anything at all to show
    var isEmpty: Bool {
        today.isEmpty && tomorrow.isEmpty && thisWeek.isEmpty
            && later.isEmpty && snoozed.isEmpty && doneToday.isEmpty
    }
    
    /// Items for a specific horizon
    func items(for horizon: TimeHorizon) -> [NudgeItem] {
        switch horizon {
        case .today:     return today
        case .tomorrow:  return tomorrow
        case .thisWeek:  return thisWeek
        case .later:     return later
        case .snoozed:   return snoozed
        case .doneToday: return doneToday
        }
    }
}

// MARK: - Grouper

/// Pure function: takes flat item lists and produces time-horizon groups.
/// No SwiftData dependency — works with pre-fetched arrays.
enum TimeHorizonGrouper {
    
    /// Maximum items shown in "Today" section (ADHD working memory research: ~3-4 items).
    /// We use 5 to give a slight buffer while keeping cognitive load low.
    static let todayCapacity = 5
    
    /// Group active items, snoozed items, and done items into time horizons.
    ///
    /// Active item placement logic:
    /// 1. Items with a due date today → Today
    /// 2. Items with a due date tomorrow → Tomorrow
    /// 3. Items with a due date this week → This Week
    /// 4. Items with a due date beyond this week → Later
    /// 5. Items WITHOUT a due date are distributed by priority:
    ///    - Overdue/stale items → Today (they need attention NOW)
    ///    - High priority → Today
    ///    - Remaining fill Today up to capacity, then overflow to Tomorrow → This Week → Later
    static func group(
        active: [NudgeItem],
        snoozed: [NudgeItem],
        doneToday: [NudgeItem]
    ) -> TimeHorizonGroups {
        
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday)
        else {
            return TimeHorizonGroups(snoozed: snoozed, doneToday: doneToday)
        }
        
        var groups = TimeHorizonGroups()
        groups.snoozed = snoozed
        groups.doneToday = doneToday
        
        // --- Pass 1: Place items with due dates ---
        var undated: [NudgeItem] = []
        
        for item in active {
            if let dueDate = item.dueDate {
                if dueDate < startOfTomorrow {
                    // Due today (or overdue)
                    groups.today.append(item)
                } else if dueDate < endOfTomorrow {
                    groups.tomorrow.append(item)
                } else if dueDate < endOfWeek {
                    groups.thisWeek.append(item)
                } else {
                    groups.later.append(item)
                }
            } else {
                undated.append(item)
            }
        }
        
        // --- Pass 2: Place undated items by urgency ---
        // Overdue, stale, and high-priority items go to Today
        var overflow: [NudgeItem] = []
        
        for item in undated {
            if item.isStale || item.isOverdue || item.priority == .high {
                groups.today.append(item)
            } else {
                overflow.append(item)
            }
        }
        
        // --- Pass 3: Fill Today up to capacity, overflow to Tomorrow → This Week → Later ---
        let todaySlots = max(0, todayCapacity - groups.today.count)
        
        for (index, item) in overflow.enumerated() {
            if index < todaySlots {
                groups.today.append(item)
            } else if index < todaySlots + 3 {
                // Next few go to tomorrow
                groups.tomorrow.append(item)
            } else {
                // Rest goes to this week or later based on age
                if item.ageInDays <= 1 {
                    groups.thisWeek.append(item)
                } else {
                    groups.later.append(item)
                }
            }
        }
        
        // --- Final: Sort within each group ---
        groups.today = sortWithinGroup(groups.today)
        groups.tomorrow = sortWithinGroup(groups.tomorrow)
        groups.thisWeek = sortWithinGroup(groups.thisWeek)
        groups.later = sortWithinGroup(groups.later)
        
        return groups
    }
    
    /// Sort items within a single time-horizon group.
    /// Priority: overdue → stale → has action/draft → by sortOrder
    private static func sortWithinGroup(_ items: [NudgeItem]) -> [NudgeItem] {
        items.sorted { a, b in
            // Overdue first
            if a.isOverdue && !b.isOverdue { return true }
            if !a.isOverdue && b.isOverdue { return false }
            
            // Stale items next
            if a.isStale && !b.isStale { return true }
            if !a.isStale && b.isStale { return false }
            
            // Items with actions/drafts get priority (Ready to Act)
            let aReady = a.hasAction || a.hasDraft
            let bReady = b.hasAction || b.hasDraft
            if aReady && !bReady { return true }
            if !aReady && bReady { return false }
            
            // Then by sortOrder
            return a.sortOrder < b.sortOrder
        }
    }
}
