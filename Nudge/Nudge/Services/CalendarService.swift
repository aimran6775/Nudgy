//
//  CalendarService.swift
//  Nudge
//
//  EventKit integration for reading user calendar events.
//  Merges calendar data into the timeline view.
//
//  Privacy: Requests read-only access to Calendar.
//  Always check authorization before fetching.
//

import EventKit
import SwiftUI

@MainActor @Observable
final class CalendarService {
    
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    
    var isAuthorized: Bool = false
    var todayEvents: [TimelineEntry] = []
    
    private init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = (status == .fullAccess || status == .authorized)
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
            if granted {
                fetchTodayEvents()
            }
            return granted
        } catch {
            print("❌ Calendar access error: \(error)")
            isAuthorized = false
            return false
        }
    }
    
    // MARK: - Fetch Events
    
    func fetchTodayEvents() {
        guard isAuthorized else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        
        todayEvents = events
            .filter { !$0.isAllDay }   // Skip all-day events for timeline
            .map { event in
                let durationMinutes = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
                let calendarColor = event.calendar.cgColor.flatMap { UIColor(cgColor: $0).hexString }
                
                return TimelineEntry(
                    id: UUID(),
                    type: .calendarEvent,
                    title: event.title ?? String(localized: "Calendar Event"),
                    emoji: "📅",
                    startTime: event.startDate,
                    durationMinutes: max(durationMinutes, 15),
                    colorHex: calendarColor,
                    isDone: event.endDate < Date(),
                    nudgeItem: nil
                )
            }
    }
}

// MARK: - UIColor hex helper

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
