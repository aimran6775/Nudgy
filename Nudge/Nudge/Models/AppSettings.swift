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

    /// Set by the app after authentication so user-specific settings are isolated per account.
    /// Not persisted directly; it’s derived from the active signed-in user.
    var activeUserID: String?

    private func scopedKey(_ base: String) -> String {
        guard let activeUserID, !activeUserID.isEmpty else { return base }
        return "\(activeUserID):\(base)"
    }
    
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
        get { UserDefaults.standard.integer(forKey: scopedKey("dailyDumpsUsed")) }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("dailyDumpsUsed")) }
    }
    
    var dailyDumpsResetDate: Date {
        get {
            (UserDefaults.standard.object(forKey: scopedKey("dailyDumpsResetDate")) as? Date) ?? .distantPast
        }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("dailyDumpsResetDate")) }
    }
    
    var savedItemsCount: Int {
        get { UserDefaults.standard.integer(forKey: scopedKey("savedItemsCount")) }
        set { UserDefaults.standard.set(newValue, forKey: scopedKey("savedItemsCount")) }
    }
    
    // MARK: - User Info
    
    var userName: String {
        get {
            access(keyPath: \.userName)
            return UserDefaults.standard.string(forKey: scopedKey("userName")) ?? ""
        }
        set {
            withMutation(keyPath: \.userName) {
                UserDefaults.standard.set(newValue, forKey: scopedKey("userName"))
            }
        }
    }
    
    // MARK: - Onboarding
    
    /// Global flag — shown before auth. Not user-scoped.
    var hasSeenIntro: Bool {
        get {
            access(keyPath: \.hasSeenIntro)
            return UserDefaults.standard.bool(forKey: "hasSeenIntro")
        }
        set {
            withMutation(keyPath: \.hasSeenIntro) {
                UserDefaults.standard.set(newValue, forKey: "hasSeenIntro")
            }
        }
    }

    var hasCompletedOnboarding: Bool {
        get {
            access(keyPath: \.hasCompletedOnboarding)
            return UserDefaults.standard.bool(forKey: scopedKey("hasCompletedOnboarding"))
        }
        set {
            withMutation(keyPath: \.hasCompletedOnboarding) {
                UserDefaults.standard.set(newValue, forKey: scopedKey("hasCompletedOnboarding"))
            }
        }
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
