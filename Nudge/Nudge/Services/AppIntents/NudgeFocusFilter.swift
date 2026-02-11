//
//  NudgeFocusFilter.swift
//  Nudge
//
//  SetFocusFilterIntent — integrates with iOS Focus modes.
//  When a Focus is active, Nudge can filter visible tasks by energy level.
//
//  Example: "Work" focus → show only "high energy" tasks
//           "Evening" focus → show only "low energy" tasks
//           "Personal" focus → show all
//
//  Users configure this in Settings → Focus → [Focus Mode] → Focus Filters → Nudge.
//

import AppIntents

/// Focus Filter for Nudge — filters tasks by energy level when a Focus mode is active.
struct NudgeFocusFilter: SetFocusFilterIntent {
    
    static var title: LocalizedStringResource = "Set Nudge Filter"
    static var description: IntentDescription = "Filter which tasks Nudge shows during this Focus."
    
    var displayRepresentation: DisplayRepresentation {
        let subtitle: String
        switch energyFilter {
        case .all:    subtitle = "Showing all tasks"
        case .high:   subtitle = "High energy tasks only"
        case .medium: subtitle = "Medium energy tasks only"
        case .low:    subtitle = "Low energy tasks only"
        }
        return DisplayRepresentation(
            title: "Nudge Filter",
            subtitle: "\(subtitle)"
        )
    }
    
    /// The energy level filter to apply during this Focus.
    @Parameter(title: "Energy Level", default: .all)
    var energyFilter: FocusEnergyFilter
    
    /// Whether to suppress notifications during this Focus.
    @Parameter(title: "Silence Nudge notifications", default: false)
    var silenceNotifications: Bool
    
    func perform() async throws -> some IntentResult {
        // Store the active filter in shared UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.tarsitgroup.nudge")
        defaults?.set(energyFilter.rawValue, forKey: "focusFilter_energyLevel")
        defaults?.set(silenceNotifications, forKey: "focusFilter_silenceNotifications")
        
        // Post notification so the app can react
        NotificationCenter.default.post(name: .nudgeDataChanged, object: nil)
        
        return .result()
    }
}

/// Energy level filter options for Focus modes.
enum FocusEnergyFilter: String, AppEnum {
    case all = "all"
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Energy Level"
    
    static var caseDisplayRepresentations: [FocusEnergyFilter: DisplayRepresentation] = [
        .all: DisplayRepresentation(title: "All Tasks", subtitle: "Show everything"),
        .high: DisplayRepresentation(title: "High Energy", subtitle: "Deep work, meetings, calls"),
        .medium: DisplayRepresentation(title: "Medium Energy", subtitle: "Emails, errands, reading"),
        .low: DisplayRepresentation(title: "Low Energy", subtitle: "Quick wins, chores, browsing")
    ]
}
