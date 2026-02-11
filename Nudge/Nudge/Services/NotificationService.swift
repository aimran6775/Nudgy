//
//  NotificationService.swift
//  Nudge
//
//  UNUserNotificationCenter wrapper — schedules, cancels, and handles notification actions.
//  Supports: snoozed item resurfacing, stale item check-ins, end-of-day prompts.
//  Registers custom "nudge-knock" notification sound + action categories.
//

import UserNotifications
import UIKit

final class NotificationService: NSObject {
    
    static let shared = NotificationService()
    
    // MARK: - Categories
    
    enum Category: String {
        case snoozedItem     = "SNOOZED_ITEM"
        case staleItem       = "STALE_ITEM"
        case endOfDay        = "END_OF_DAY"
    }
    
    // MARK: - Actions
    
    enum Action: String {
        case callNow         = "CALL_NOW"
        case sendText        = "SEND_TEXT"
        case openLink        = "OPEN_LINK"
        case snoozeTomorrow  = "SNOOZE_TOMORROW"
        case markDone        = "MARK_DONE"
        case viewItem        = "VIEW_ITEM"
    }
    
    // MARK: - Notification Templates
    
    private let staleTemplates: [String] = [
        String(localized: "You've had \"%@\" for %d days. Want to do it now or let it go?"),
        String(localized: "\"%@\" has been waiting %d days. Quick 5-minute sprint?"),
        String(localized: "Hey — \"%@\" is still here (%d days). Tackle it or drop it?"),
        String(localized: "\"%@\" — %d days old. Maybe today's the day?"),
        String(localized: "Still thinking about \"%@\"? It's been %d days."),
    ]
    
    private let endOfDayTemplates: [String] = [
        String(localized: "You've got one big thing left. 15-minute sprint?"),
        String(localized: "Almost done for today — one more item to go."),
        String(localized: "Quick win available before you wrap up for the night."),
        String(localized: "One thing left on your plate. You've got this."),
    ]
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    /// Request notification permission and register categories.
    /// Call on first snooze or brain dump.
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                registerCategories()
            }
            
            return granted
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }
    
    /// Register notification action categories
    private func registerCategories() {
        let center = UNUserNotificationCenter.current()
        
        // Snoozed item: actionable buttons based on item type
        let snoozedActions = [
            UNNotificationAction(
                identifier: Action.viewItem.rawValue,
                title: String(localized: "View"),
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Action.snoozeTomorrow.rawValue,
                title: String(localized: "Tomorrow"),
                options: [.destructive]
            ),
        ]
        
        // Snoozed item with call action
        let snoozedCallActions = [
            UNNotificationAction(
                identifier: Action.callNow.rawValue,
                title: String(localized: "📞 Call Now"),
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Action.sendText.rawValue,
                title: String(localized: "💬 Send Text"),
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Action.snoozeTomorrow.rawValue,
                title: String(localized: "⏰ Tomorrow"),
                options: [.destructive]
            ),
        ]
        
        // Stale item
        let staleActions = [
            UNNotificationAction(
                identifier: Action.markDone.rawValue,
                title: String(localized: "Done ✓"),
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Action.snoozeTomorrow.rawValue,
                title: String(localized: "Tomorrow"),
                options: [.destructive]
            ),
        ]
        
        // End of day
        let eodActions = [
            UNNotificationAction(
                identifier: Action.viewItem.rawValue,
                title: String(localized: "Let's do it"),
                options: [.foreground]
            ),
        ]
        
        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(
                identifier: Category.snoozedItem.rawValue,
                actions: snoozedActions,
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: "SNOOZED_ITEM_CALL",
                actions: snoozedCallActions,
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.staleItem.rawValue,
                actions: staleActions,
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.endOfDay.rawValue,
                actions: eodActions,
                intentIdentifiers: []
            ),
        ]
        
        center.setNotificationCategories(categories)
        center.delegate = self
    }
    
    // MARK: - Schedule Snoozed Item Notification
    
    func scheduleSnoozedNotification(for item: NudgeItem) {
        guard let snoozedUntil = item.snoozedUntil else { return }
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to nudge")
        content.body = item.content
        content.userInfo = ["itemID": item.id.uuidString]
        
        // Custom notification sound (falls back to default if .caf missing)
        if let _ = Bundle.main.url(forResource: "nudge-knock", withExtension: "caf") {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("nudge-knock.caf"))
        } else {
            content.sound = .default
        }
        
        // Use call-specific category if item has call action
        if item.actionType == .call || item.actionType == .text {
            content.categoryIdentifier = "SNOOZED_ITEM_CALL"
        } else {
            content.categoryIdentifier = Category.snoozedItem.rawValue
        }
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: snoozedUntil
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "snooze-\(item.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Schedule Stale Item Notification
    
    func scheduleStaleNotification(for item: NudgeItem, settings: AppSettings) {
        // Check if delivery time (30 min from now) would be during quiet hours
        let deliveryTime = Date().addingTimeInterval(1800)
        guard !settings.isDateInQuietHours(deliveryTime) else { return }
        
        // Check daily nudge cap
        let todayKey = "nudgesSentToday"
        let resetKey = "nudgesResetDate"
        let calendar = Calendar.current
        let lastReset = (UserDefaults.standard.object(forKey: resetKey) as? Date) ?? .distantPast
        if !calendar.isDateInToday(lastReset) {
            UserDefaults.standard.set(0, forKey: todayKey)
            UserDefaults.standard.set(Date(), forKey: resetKey)
        }
        let sentToday = UserDefaults.standard.integer(forKey: todayKey)
        guard sentToday < settings.maxDailyNudges else { return }
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Gentle nudge")
        
        let template = staleTemplates.randomElement() ?? staleTemplates[0]
        content.body = String(format: template, item.content, item.ageInDays)
        content.categoryIdentifier = Category.staleItem.rawValue
        content.userInfo = ["itemID": item.id.uuidString]
        
        // Custom notification sound
        if let _ = Bundle.main.url(forResource: "nudge-knock", withExtension: "caf") {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("nudge-knock.caf"))
        } else {
            content.sound = .default
        }
        
        // Schedule for 30 minutes from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1800, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "stale-\(item.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        // Increment sent counter
        UserDefaults.standard.set(sentToday + 1, forKey: todayKey)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Schedule End-of-Day Prompt
    
    func scheduleEndOfDayPrompt(remainingCount: Int, settings: AppSettings) {
        guard remainingCount > 0 else { return }
        
        // Build 4pm today
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 16
        components.minute = 0
        
        guard let targetDate = calendar.date(from: components) else { return }
        
        // If 4pm already passed today, skip (don't schedule in the past)
        guard targetDate > Date() else { return }
        
        // If 4pm falls in quiet hours, skip
        guard !settings.isDateInQuietHours(targetDate) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Almost there")
        content.body = endOfDayTemplates.randomElement() ?? endOfDayTemplates[0]
        content.categoryIdentifier = Category.endOfDay.rawValue
        content.sound = .default
        
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "eod-\(Date().formatted(.iso8601.year().month().day()))",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Cancel
    
    func cancelNotification(for itemID: UUID) {
        let identifiers = [
            "snooze-\(itemID.uuidString)",
            "stale-\(itemID.uuidString)",
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
    
    /// Handle notification action tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let itemIDString = userInfo["itemID"] as? String
        
        let action: String
        
        switch response.actionIdentifier {
        case Action.callNow.rawValue:
            action = "call"
        case Action.sendText.rawValue:
            action = "text"
        case Action.snoozeTomorrow.rawValue:
            action = "snoozeTomorrow"
        case Action.markDone.rawValue:
            action = "markDone"
        case Action.viewItem.rawValue, UNNotificationDefaultActionIdentifier:
            action = "view"
        default:
            return
        }
        
        // Post on the main thread — NotificationCenter observers expect it
        await MainActor.run {
            NotificationCenter.default.post(
                name: .nudgeNotificationAction,
                object: nil,
                userInfo: ["action": action, "itemID": itemIDString ?? ""]
            )
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let nudgeNotificationAction = Notification.Name("nudgeNotificationAction")
}
