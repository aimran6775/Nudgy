//
//  Extensions.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

// MARK: - Date Extensions

extension Date {
    
    /// Relative time description: "2 hours ago", "3 days ago", etc.
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Short time display: "9:00 AM", "3:30 PM"
    var shortTime: String {
        formatted(date: .omitted, time: .shortened)
    }
    
    /// Friendly date: "Tomorrow morning", "This weekend", etc.
    var friendlySnoozeDescription: String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            return String(localized: "Later today at \(shortTime)")
        } else if calendar.isDateInTomorrow(self) {
            return String(localized: "Tomorrow at \(shortTime)")
        } else {
            return formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
        }
    }
    
    /// Days since this date (for stale detection)
    var daysSince: Int {
        Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
    }
    
    /// Whether this date is in the past
    var isPast: Bool {
        self < Date()
    }
    
    // MARK: Snooze Presets
    
    /// 3 hours from now
    static var laterToday: Date {
        Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date()
    }
    
    /// Tomorrow at 9am
    static var tomorrowMorning: Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
    
    /// This Saturday at 10am
    static var thisWeekend: Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        // Saturday = 7
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let saturday = calendar.date(byAdding: .day, value: max(daysUntilSaturday, 1), to: today) ?? today
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: saturday) ?? saturday
    }
    
    /// Next Monday at 9am
    static var nextWeek: Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        // Monday = 2
        let daysUntilMonday = (2 - weekday + 7) % 7
        let monday = calendar.date(byAdding: .day, value: max(daysUntilMonday, 1), to: today) ?? today
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: monday) ?? monday
    }
}

// MARK: - URL Extensions

extension URL {
    /// Extract a display-friendly hostname: "apple.com" from "https://www.apple.com/iphone"
    var displayHost: String {
        (host() ?? absoluteString).replacingOccurrences(of: "www.", with: "")
    }
}

// MARK: - String Extensions

extension String {
    /// Truncate to max length with ellipsis
    nonisolated func truncated(to maxLength: Int = 80) -> String {
        if count <= maxLength { return self }
        return String(prefix(maxLength)) + "…"
    }
}
