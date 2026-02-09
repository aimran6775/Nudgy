//
//  AppSettings.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

/// Lightweight settings stored in UserDefaults (not SwiftData).
/// No migrations, no model container complexity.
@Observable
final class AppSettings {
    
    // MARK: - Quiet Hours
    
    var quietHoursStart: Int {
        get { UserDefaults.standard.object(forKey: "quietHoursStart") as? Int ?? 21 }
        set { UserDefaults.standard.set(newValue, forKey: "quietHoursStart") }
    }
    
    var quietHoursEnd: Int {
        get { UserDefaults.standard.object(forKey: "quietHoursEnd") as? Int ?? 8 }
        set { UserDefaults.standard.set(newValue, forKey: "quietHoursEnd") }
    }
    
    // MARK: - Notifications
    
    var maxDailyNudges: Int {
        get { UserDefaults.standard.object(forKey: "maxDailyNudges") as? Int ?? 3 }
        set { UserDefaults.standard.set(newValue, forKey: "maxDailyNudges") }
    }
    
    // MARK: - Live Activity
    
    var liveActivityEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "liveActivityEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "liveActivityEnabled") }
    }
    
    var liveActivityPromptShown: Bool {
        get { UserDefaults.standard.bool(forKey: "liveActivityPromptShown") }
        set { UserDefaults.standard.set(newValue, forKey: "liveActivityPromptShown") }
    }
    
    // MARK: - Subscription
    
    var isPro: Bool {
        get { UserDefaults.standard.bool(forKey: "isPro") }
        set { UserDefaults.standard.set(newValue, forKey: "isPro") }
    }
    
    // MARK: - Usage Tracking (Free Tier Limits)
    
    var dailyDumpsUsed: Int {
        get { UserDefaults.standard.integer(forKey: "dailyDumpsUsed") }
        set { UserDefaults.standard.set(newValue, forKey: "dailyDumpsUsed") }
    }
    
    var dailyDumpsResetDate: Date {
        get {
            (UserDefaults.standard.object(forKey: "dailyDumpsResetDate") as? Date) ?? .distantPast
        }
        set { UserDefaults.standard.set(newValue, forKey: "dailyDumpsResetDate") }
    }
    
    var savedItemsCount: Int {
        get { UserDefaults.standard.integer(forKey: "savedItemsCount") }
        set { UserDefaults.standard.set(newValue, forKey: "savedItemsCount") }
    }
    
    // MARK: - User Info
    
    var userName: String {
        get { UserDefaults.standard.string(forKey: "userName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "userName") }
    }
    
    // MARK: - Onboarding
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }
    
    // MARK: - Computed Helpers
    
    /// Whether the user can do another brain dump (free tier check)
    var canDoBrainDump: Bool {
        isPro || dailyDumpsUsed < FreeTierLimits.brainDumpsPerDay
    }
    
    /// Whether the user can save another shared item (free tier check)
    var canSaveSharedItem: Bool {
        isPro || savedItemsCount < FreeTierLimits.savedItems
    }
    
    /// Whether we're currently in quiet hours
    var isInQuietHours: Bool {
        isDateInQuietHours(Date())
    }
    
    /// Whether a specific date falls within quiet hours
    func isDateInQuietHours(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if quietHoursStart > quietHoursEnd {
            // Wraps midnight: e.g., 21-8 means 9pm → 8am
            return hour >= quietHoursStart || hour < quietHoursEnd
        } else {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
    }
    
    /// Returns the next date when quiet hours end
    func nextQuietHoursEnd(after date: Date = Date()) -> Date {
        let calendar = Calendar.current
        var target = calendar.date(bySettingHour: quietHoursEnd, minute: 0, second: 0, of: date) ?? date
        // If that time has already passed today, use tomorrow
        if target <= date {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target
    }
    
    /// Reset daily dump counter if needed (call on app launch)
    func resetDailyCountersIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(dailyDumpsResetDate) {
            dailyDumpsUsed = 0
            dailyDumpsResetDate = Date()
        }
    }
    
    /// Record a brain dump usage
    func recordBrainDump() {
        dailyDumpsUsed += 1
    }
}
