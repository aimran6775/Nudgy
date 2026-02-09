//
//  NudgeTests.swift
//  NudgeTests
//
//  Unit tests for Nudge — models, logic, extensions, and services.
//  Run with ⌘U in Xcode.
//

import Testing
import SwiftData
import SwiftUI
import Foundation
@testable import Nudge

// MARK: - NudgeItem Model Tests

struct NudgeItemTests {
    
    @Test func itemDefaultState() {
        let item = NudgeItem(content: "Test task")
        #expect(item.status == .active)
        #expect(item.sourceType == .manual)
        #expect(item.actionType == nil)
        #expect(item.emoji == nil)
        #expect(item.completedAt == nil)
        #expect(item.snoozedUntil == nil)
    }
    
    @Test func markDone() {
        let item = NudgeItem(content: "Test task")
        item.markDone()
        #expect(item.status == .done)
        #expect(item.completedAt != nil)
    }
    
    @Test func snoozeAndResurface() {
        let item = NudgeItem(content: "Test task")
        let future = Date().addingTimeInterval(3600)
        
        item.snooze(until: future)
        #expect(item.status == .snoozed)
        #expect(item.snoozedUntil == future)
        
        item.resurface()
        #expect(item.status == .active)
        #expect(item.snoozedUntil == nil)
    }
    
    @Test func dropSetsStatusToDropped() {
        let item = NudgeItem(content: "Test task")
        item.drop()
        #expect(item.status == .dropped)
    }
    
    @Test func skipUpdatesOrder() {
        let item = NudgeItem(content: "Test task", sortOrder: 1)
        item.skip(newOrder: 99)
        #expect(item.sortOrder == 99)
    }
    
    @Test func staleDetection() {
        let item = NudgeItem(content: "Old task")
        item.createdAt = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        #expect(item.isStale == true)
        #expect(item.ageInDays >= 4)
    }
    
    @Test func freshItemNotStale() {
        let item = NudgeItem(content: "Fresh task")
        #expect(item.isStale == false)
        #expect(item.ageInDays == 0)
    }
    
    @Test func overdueDetection() {
        let item = NudgeItem(content: "Snoozed task")
        item.snooze(until: Date().addingTimeInterval(-60))
        #expect(item.isOverdue == true)
        #expect(item.shouldResurface == true)
    }
    
    @Test func notOverdueWhenSnoozedInFuture() {
        let item = NudgeItem(content: "Snoozed task")
        item.snooze(until: Date().addingTimeInterval(3600))
        #expect(item.isOverdue == false)
        #expect(item.shouldResurface == false)
    }
    
    @Test func hasActionDetection() {
        let noAction = NudgeItem(content: "No action")
        #expect(noAction.hasAction == false)
        
        let withAction = NudgeItem(content: "Call task", actionType: .call)
        #expect(withAction.hasAction == true)
    }
    
    @Test func hasDraftDetection() {
        let item = NudgeItem(content: "Task")
        #expect(item.hasDraft == false)
        
        item.aiDraft = "Hey, just following up..."
        #expect(item.hasDraft == true)
        
        item.aiDraft = ""
        #expect(item.hasDraft == false)
    }
    
    @Test func accentStatusMapping() {
        let fresh = NudgeItem(content: "Fresh")
        #expect(fresh.accentStatus == .active)
        
        let stale = NudgeItem(content: "Stale")
        stale.createdAt = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        #expect(stale.accentStatus == .stale)
        
        let done = NudgeItem(content: "Done")
        done.markDone()
        #expect(done.accentStatus == .complete)
        
        let overdue = NudgeItem(content: "Overdue")
        overdue.snooze(until: Date().addingTimeInterval(-120))
        #expect(overdue.accentStatus == .overdue)
    }
    
    @Test func sourceTypeRoundTrip() {
        let item = NudgeItem(content: "Voice", sourceType: .voiceDump)
        #expect(item.sourceType == .voiceDump)
        #expect(item.sourceTypeRaw == "voice")
        
        item.sourceType = .share
        #expect(item.sourceTypeRaw == "share")
    }
    
    @Test func actionTypeRoundTrip() {
        let item = NudgeItem(content: "Call", actionType: .call)
        #expect(item.actionType == .call)
        #expect(item.actionTypeRaw == "CALL")
        
        item.actionType = .email
        #expect(item.actionTypeRaw == "EMAIL")
        
        item.actionType = nil
        #expect(item.actionTypeRaw == nil)
    }
}

// MARK: - Enum Tests

struct EnumTests {
    
    @Test func itemStatusRawValues() {
        #expect(ItemStatus(rawValue: "active") == .active)
        #expect(ItemStatus(rawValue: "snoozed") == .snoozed)
        #expect(ItemStatus(rawValue: "done") == .done)
        #expect(ItemStatus(rawValue: "dropped") == .dropped)
        #expect(ItemStatus(rawValue: "invalid") == nil)
    }
    
    @Test func actionTypeLabelsExist() {
        for action in ActionType.allCases {
            #expect(!action.label.isEmpty)
            #expect(!action.icon.isEmpty)
        }
    }
    
    @Test func sourceTypeLabelsExist() {
        for source in SourceType.allCases {
            #expect(!source.label.isEmpty)
            #expect(!source.icon.isEmpty)
        }
    }
}

// MARK: - Date Extension Tests

struct DateExtensionTests {
    
    @Test func isPast() {
        let past = Date().addingTimeInterval(-60)
        #expect(past.isPast == true)
        
        let future = Date().addingTimeInterval(60)
        #expect(future.isPast == false)
    }
    
    @Test func daysSince() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        #expect(threeDaysAgo.daysSince >= 3)
    }
    
    @Test func snoozePresetsAreFuture() {
        let laterToday = Date.laterToday
        #expect(laterToday > Date())
        
        let tomorrowMorning = Date.tomorrowMorning
        #expect(tomorrowMorning > Date())
        
        let thisWeekend = Date.thisWeekend
        #expect(thisWeekend > Date())
        
        let nextWeek = Date.nextWeek
        #expect(nextWeek > Date())
    }
    
    @Test func tomorrowMorningIsAt9AM() {
        let morning = Date.tomorrowMorning
        let hour = Calendar.current.component(.hour, from: morning)
        #expect(hour == 9)
    }
}

// MARK: - String Extension Tests

struct StringExtensionTests {
    
    @Test func truncateShortString() {
        let short = "Hello"
        #expect(short.truncated(to: 10) == "Hello")
    }
    
    @Test func truncateLongString() {
        let long = "This is a very long string that should be truncated"
        let result = long.truncated(to: 20)
        #expect(result.count == 21) // 20 chars + ellipsis
        #expect(result.hasSuffix("…"))
    }
    
    @Test func truncateExactLength() {
        let exact = "12345"
        #expect(exact.truncated(to: 5) == "12345")
    }
}

// MARK: - Free Tier Limits Tests

struct FreeTierTests {
    
    @Test func freeTierConstants() {
        #expect(FreeTierLimits.maxDailyBrainDumps == 3)
        #expect(FreeTierLimits.maxSavedItems == 5)
        #expect(FreeTierLimits.brainDumpsPerDay == FreeTierLimits.maxDailyBrainDumps)
        #expect(FreeTierLimits.savedItems == FreeTierLimits.maxSavedItems)
    }
}

// MARK: - StoreKit Product IDs Tests

struct StoreKitTests {
    
    @Test func productIDsNonEmpty() {
        #expect(!StoreKitProducts.proMonthly.isEmpty)
        #expect(!StoreKitProducts.proYearly.isEmpty)
        #expect(StoreKitProducts.allProducts.count == 2)
    }
    
    @Test func productIDsFollowConvention() {
        #expect(StoreKitProducts.proMonthly.hasPrefix("com.nudge."))
        #expect(StoreKitProducts.proYearly.hasPrefix("com.nudge."))
    }
}

// MARK: - RecordingConfig Tests

struct RecordingConfigTests {
    
    @Test func recordingLimits() {
        #expect(RecordingConfig.maxDuration == 55)
        #expect(RecordingConfig.countdownThreshold == 10)
        #expect(RecordingConfig.countdownThreshold < RecordingConfig.maxDuration)
    }
}

// MARK: - Color(hex:) Tests

struct ColorHexTests {
    
    @Test func sixCharHex() {
        // Should not crash
        let _ = SwiftUI.Color(hex: "007AFF")
        let _ = SwiftUI.Color(hex: "#FF453A")
        let _ = SwiftUI.Color(hex: "000000")
        let _ = SwiftUI.Color(hex: "FFFFFF")
    }
    
    @Test func eightCharHex() {
        let _ = SwiftUI.Color(hex: "FF007AFF")
    }
    
    @Test func invalidHexFallsBack() {
        // Should not crash on invalid input
        let _ = SwiftUI.Color(hex: "")
        let _ = SwiftUI.Color(hex: "XYZ")
        let _ = SwiftUI.Color(hex: "12")
    }
}

// MARK: - BrainDump Model Tests

struct BrainDumpTests {
    
    @Test func defaultInit() {
        let dump = BrainDump(rawTranscript: "Call mom and buy groceries")
        #expect(dump.rawTranscript == "Call mom and buy groceries")
        #expect(dump.items.isEmpty)
        #expect(dump.taskCount == 0)
        #expect(dump.wasSingleItem == true)
    }
}

// MARK: - ShareExtensionPayload Tests

struct SharePayloadTests {
    
    @Test func encodeDecodeRoundTrip() throws {
        let payload = ShareExtensionPayload(
            content: "Check out this link",
            url: "https://example.com",
            preview: "Example Domain",
            snoozedUntil: Date(),
            savedAt: Date()
        )
        
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ShareExtensionPayload.self, from: data)
        
        #expect(decoded.content == payload.content)
        #expect(decoded.url == payload.url)
        #expect(decoded.preview == payload.preview)
    }
    
    @Test func encodeDecodeWithNilOptionals() throws {
        let payload = ShareExtensionPayload(
            content: "Just text",
            url: nil,
            preview: nil,
            snoozedUntil: Date(),
            savedAt: Date()
        )
        
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ShareExtensionPayload.self, from: data)
        
        #expect(decoded.content == "Just text")
        #expect(decoded.url == nil)
        #expect(decoded.preview == nil)
    }
}

// MARK: - NotificationConfig Tests

struct NotificationConfigTests {
    
    @Test func notificationDefaults() {
        #expect(NotificationConfig.maxDailyNudges == 3)
        #expect(NotificationConfig.defaultQuietHoursStart == 21)
        #expect(NotificationConfig.defaultQuietHoursEnd == 8)
        #expect(NotificationConfig.staleThresholdDays == 3)
    }
}

// MARK: - URL Extension Tests

struct URLExtensionTests {
    
    @Test func displayHostStripsWWW() {
        let url = URL(string: "https://www.apple.com/iphone")!
        #expect(url.displayHost == "apple.com")
    }
    
    @Test func displayHostWithoutWWW() {
        let url = URL(string: "https://docs.google.com/spreadsheets")!
        #expect(url.displayHost == "docs.google.com")
    }
}

// MARK: - ExtractedTask Parsing Tests

struct ExtractedTaskParsingTests {
    
    @Test func parsedDueDateTomorrow() {
        let task = ExtractedTask(content: "Test", emoji: "📝", actionType: "", contactName: "", actionTarget: "", isActionable: true, priority: "medium", dueDateString: "tomorrow")
        #expect(task.parsedDueDate != nil)
        let cal = Calendar.current
        let expected = cal.date(byAdding: .day, value: 1, to: Date())!
        #expect(cal.isDate(task.parsedDueDate!, inSameDayAs: expected))
    }
    
    @Test func parsedDueDateToday() {
        let task = ExtractedTask(content: "Test", emoji: "📝", actionType: "", contactName: "", actionTarget: "", isActionable: true, priority: "medium", dueDateString: "today")
        #expect(task.parsedDueDate != nil)
        let cal = Calendar.current
        #expect(cal.isDateInToday(task.parsedDueDate!))
    }
    
    @Test func parsedDueDateISO() {
        let task = ExtractedTask(content: "Test", emoji: "📝", actionType: "", contactName: "", actionTarget: "", isActionable: true, priority: "high", dueDateString: "2026-03-15")
        #expect(task.parsedDueDate != nil)
        // Verify the date is in March 2026 (timezone-safe)
        let cal = Calendar.current
        let comps = cal.dateComponents([.month, .day], from: task.parsedDueDate!)
        #expect(comps.month == 3)
        #expect(comps.day == 15)
    }
    
    @Test func parsedDueDateEmpty() {
        let task = ExtractedTask(content: "Test", emoji: "📝", actionType: "", contactName: "", actionTarget: "", isActionable: true, priority: "low", dueDateString: "")
        #expect(task.parsedDueDate == nil)
    }
    
    @Test func mappedPriorityHigh() {
        let task = ExtractedTask(content: "Test", emoji: "📝", actionType: "", contactName: "", actionTarget: "", isActionable: true, priority: "high", dueDateString: "")
        #expect(task.mappedPriority == .high)
    }
    
    @Test func mappedPriorityLow() {
        let task = ExtractedTask(content: "Test", emoji: "📝", actionType: "", contactName: "", actionTarget: "", isActionable: true, priority: "low", dueDateString: "")
        #expect(task.mappedPriority == .low)
    }
    
    @Test func mappedPriorityDefault() {
        let task = ExtractedTask(content: "Test", emoji: "📝", actionType: "", contactName: "", actionTarget: "", isActionable: true, priority: "unknown", dueDateString: "")
        #expect(task.mappedPriority == .medium)
    }
    
    @Test func mappedActionTypeCall() {
        let task = ExtractedTask(content: "Test", emoji: "📞", actionType: "CALL", contactName: "Mom", actionTarget: "", isActionable: true)
        #expect(task.mappedActionType == .call)
    }
    
    @Test @MainActor func nextDateForDayFutureThisMonth() {
        let cal = Calendar.current
        let currentDay = cal.component(.day, from: Date())
        let futureDay = min(currentDay + 5, 28) // safe day
        let result = NudgyTaskExtractor.nextDateForDay(futureDay)
        #expect(!result.isEmpty)
        // Should be this month if day hasn't passed
        if futureDay > currentDay {
            let currentMonth = cal.component(.month, from: Date())
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            if let date = df.date(from: result) {
                #expect(cal.component(.month, from: date) == currentMonth)
            }
        }
    }
    
    @Test func fallbackExtractionHasContent() {
        // Test the fallback produces valid output
        let task = ExtractedTask(content: "Call the dentist", emoji: "📝", actionType: "", contactName: "", actionTarget: "", isActionable: true, priority: "medium", dueDateString: "")
        #expect(task.content == "Call the dentist")
        #expect(task.isActionable == true)
    }
}

// MARK: - TaskPriority Tests

struct TaskPriorityTests {
    
    @Test func priorityIcons() {
        #expect(!TaskPriority.high.icon.isEmpty)
        #expect(!TaskPriority.medium.icon.isEmpty)
        #expect(!TaskPriority.low.icon.isEmpty)
    }
    
    @Test func prioritySortOrder() {
        #expect(TaskPriority.high.sortWeight < TaskPriority.medium.sortWeight)
        #expect(TaskPriority.medium.sortWeight < TaskPriority.low.sortWeight)
    }
    
    @Test func priorityRawValues() {
        #expect(TaskPriority.high.rawValue == "high")
        #expect(TaskPriority.medium.rawValue == "medium")
        #expect(TaskPriority.low.rawValue == "low")
    }
}
