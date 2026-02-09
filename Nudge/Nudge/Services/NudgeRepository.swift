//
//  NudgeRepository.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftData
import SwiftUI

/// Central data access layer for NudgeItem CRUD and ordering.
/// All SwiftData queries go through here — views never touch ModelContext directly.
@MainActor @Observable
final class NudgeRepository {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Fetch Active Queue
    
    /// Fetch the ordered queue for One-Thing View.
    /// Priority: items with due times first → overdue → most recent → snoozed resurfacing
    func fetchActiveQueue() -> [NudgeItem] {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "active"
        }
        
        var descriptor = FetchDescriptor<NudgeItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        descriptor.fetchLimit = 50
        
        do {
            let items = try modelContext.fetch(descriptor)
            return prioritize(items)
        } catch {
            print("❌ Failed to fetch active queue: \(error)")
            return []
        }
    }
    
    /// Fetch the next single item for One-Thing View
    func fetchNextItem() -> NudgeItem? {
        fetchActiveQueue().first
    }
    
    // MARK: - Fetch By Status
    
    /// Fetch all snoozed items
    func fetchSnoozed() -> [NudgeItem] {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "snoozed"
        }
        
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.snoozedUntil, order: .forward)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch snoozed items: \(error)")
            return []
        }
    }
    
    /// Fetch items completed today
    func fetchCompletedToday() -> [NudgeItem] {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "done"
        }
        
        let descriptor = FetchDescriptor<NudgeItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        
        do {
            let items = try modelContext.fetch(descriptor)
            // Filter in-memory to avoid force-unwrapping optionals in #Predicate
            let startOfDay = Calendar.current.startOfDay(for: Date())
            return items.filter { item in
                guard let completedAt = item.completedAt else { return false }
                return completedAt >= startOfDay
            }
        } catch {
            print("❌ Failed to fetch completed items: \(error)")
            return []
        }
    }
    
    /// Fetch all items for the All Items screen
    func fetchAllGrouped() -> (active: [NudgeItem], snoozed: [NudgeItem], doneToday: [NudgeItem]) {
        return (
            active: fetchActiveQueue(),
            snoozed: fetchSnoozed(),
            doneToday: fetchCompletedToday()
        )
    }
    
    // MARK: - Resurface Snoozed Items
    
    /// Check for snoozed items that should resurface and activate them.
    /// Call this on app launch and periodically.
    func resurfaceExpiredSnoozes() {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "snoozed"
        }
        
        let descriptor = FetchDescriptor<NudgeItem>(predicate: predicate)
        
        do {
            let snoozed = try modelContext.fetch(descriptor)
            let now = Date()
            // Filter in-memory to avoid force-unwrapping optionals in #Predicate
            let expired = snoozed.filter { item in
                guard let snoozedUntil = item.snoozedUntil else { return false }
                return snoozedUntil <= now
            }
            for item in expired {
                item.resurface()
            }
            if !expired.isEmpty {
                save()
            }
        } catch {
            print("❌ Failed to resurface snoozed items: \(error)")
        }
    }
    
    // MARK: - Create
    
    /// Insert a new item from a brain dump
    func createFromBrainDump(
        content: String,
        emoji: String?,
        actionType: ActionType?,
        actionTarget: String? = nil,
        contactName: String?,
        priority: TaskPriority? = nil,
        dueDate: Date? = nil,
        brainDump: BrainDump
    ) -> NudgeItem {
        let maxOrder = fetchMaxSortOrder()
        let item = NudgeItem(
            content: content,
            sourceType: .voiceDump,
            emoji: emoji,
            actionType: actionType,
            actionTarget: actionTarget,
            contactName: contactName,
            sortOrder: maxOrder + 1,
            priority: priority,
            dueDate: dueDate
        )
        item.brainDump = brainDump
        modelContext.insert(item)
        return item
    }
    
    /// Insert a new item from Share Extension
    func createFromShare(
        content: String,
        url: String?,
        preview: String?,
        snoozedUntil: Date
    ) -> NudgeItem {
        let maxOrder = fetchMaxSortOrder()
        let item = NudgeItem(
            content: content,
            sourceType: .share,
            sourceUrl: url,
            sourcePreview: preview,
            actionType: url != nil ? .openLink : nil,
            actionTarget: url,
            sortOrder: maxOrder + 1
        )
        item.snooze(until: snoozedUntil)
        modelContext.insert(item)
        save()
        return item
    }
    
    /// Insert a manually created item
    func createManual(content: String) -> NudgeItem {
        let maxOrder = fetchMaxSortOrder()
        let item = NudgeItem(
            content: content,
            sourceType: .manual,
            sortOrder: maxOrder + 1
        )
        modelContext.insert(item)
        save()
        return item
    }
    
    /// Insert a manually created item with AI-extracted details (emoji, action type, contact)
    func createManualWithDetails(
        content: String,
        emoji: String?,
        actionType: ActionType?,
        actionTarget: String? = nil,
        contactName: String?
    ) -> NudgeItem {
        let maxOrder = fetchMaxSortOrder()
        let item = NudgeItem(
            content: content,
            sourceType: .manual,
            emoji: emoji,
            actionType: actionType,
            actionTarget: actionTarget,
            contactName: contactName,
            sortOrder: maxOrder + 1
        )
        modelContext.insert(item)
        save()
        return item
    }
    
    // MARK: - Actions
    
    /// Mark item as done
    func markDone(_ item: NudgeItem) {
        item.markDone()
        save()
    }
    
    /// Snooze item
    func snooze(_ item: NudgeItem, until date: Date) {
        item.snooze(until: date)
        save()
    }
    
    /// Skip item (move to end of queue)
    func skip(_ item: NudgeItem) {
        let maxOrder = fetchMaxSortOrder()
        item.skip(newOrder: maxOrder + 1)
        save()
    }
    
    /// Drop (soft delete) item
    func drop(_ item: NudgeItem) {
        item.drop()
        save()
    }
    
    /// Permanently delete item
    func delete(_ item: NudgeItem) {
        // Cancel any pending notifications for this item
        NotificationService.shared.cancelNotification(for: item.id)
        modelContext.delete(item)
        save()
    }
    
    /// Undo a done action — restore item to active
    func undoDone(_ item: NudgeItem, restoreSortOrder: Int) {
        item.status = .active
        item.completedAt = nil
        item.sortOrder = restoreSortOrder
        save()
    }
    
    /// Resurface a snoozed item — bring it back to active
    func resurfaceItem(_ item: NudgeItem) {
        item.resurface()
        // Cancel the pending snooze notification
        NotificationService.shared.cancelNotification(for: item.id)
        save()
    }
    
    /// Update AI draft on item
    func updateDraft(_ item: NudgeItem, draft: String, subject: String? = nil) {
        item.aiDraft = draft
        item.aiDraftSubject = subject
        item.draftGeneratedAt = Date()
        save()
    }
    
    // MARK: - Counts
    
    /// Total active items count (for "3 of 7" indicator)
    func activeCount() -> Int {
        let predicate = #Predicate<NudgeItem> {
            $0.statusRaw == "active"
        }
        let descriptor = FetchDescriptor<NudgeItem>(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    /// Total completed today
    func completedTodayCount() -> Int {
        fetchCompletedToday().count
    }
    
    // MARK: - Share Extension Ingest
    
    /// Ingest items from Share Extension via App Group UserDefaults.
    /// Called on app launch and when app becomes active.
    func ingestFromShareExtension() {
        guard let defaults = UserDefaults(suiteName: AppGroupID.suiteName) else { return }
        guard let data = defaults.data(forKey: AppGroupID.pendingItemsKey) else { return }
        
        do {
            let pendingItems = try JSONDecoder().decode([ShareExtensionPayload].self, from: data)
            
            for payload in pendingItems {
                _ = createFromShare(
                    content: payload.content,
                    url: payload.url,
                    preview: payload.preview,
                    snoozedUntil: payload.snoozedUntil
                )
            }
            
            // Clear after ingestion
            defaults.removeObject(forKey: AppGroupID.pendingItemsKey)
        } catch {
            print("❌ Failed to ingest share extension items: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchMaxSortOrder() -> Int {
        let descriptor = FetchDescriptor<NudgeItem>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        var limitedDescriptor = descriptor
        limitedDescriptor.fetchLimit = 1
        
        let items = (try? modelContext.fetch(limitedDescriptor)) ?? []
        return items.first?.sortOrder ?? 0
    }
    
    /// Prioritize items: due times → overdue → stale → recent → snoozed resurfacing
    private func prioritize(_ items: [NudgeItem]) -> [NudgeItem] {
        items.sorted { a, b in
            // Overdue items first
            if a.isOverdue && !b.isOverdue { return true }
            if !a.isOverdue && b.isOverdue { return false }
            
            // Stale items (3+ days) before non-stale
            if a.isStale && !b.isStale { return true }
            if !a.isStale && b.isStale { return false }
            
            // Then by sortOrder
            return a.sortOrder < b.sortOrder
        }
    }
    
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("❌ SwiftData save failed: \(error)")
        }
    }
}

// MARK: - Share Extension Payload

/// Lightweight JSON payload written by the Share Extension.
/// Must match the definition in NudgeShareExtension/ShareViewController.swift.
struct ShareExtensionPayload: Codable {
    let content: String
    let url: String?
    let preview: String?
    let snoozedUntil: Date
    let savedAt: Date
}

// MARK: - App Group Constants

enum AppGroupID {
    static let suiteName = "group.com.nudge.app"
    static let pendingItemsKey = "pendingShareItems"
}
