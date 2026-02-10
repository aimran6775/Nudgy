//
//  TimelineView.swift
//  Nudge
//
//  A vertical visual timeline of today's scheduled tasks.
//  Shows a time axis with task blocks, a "now" indicator,
//  and optional calendar events merged in.
//
//  Inspired by Tiimo's visual timeline — but optimized for
//  ADHD with cleaner contrast and less visual overload.
//

import SwiftUI
import SwiftData

// MARK: - Timeline Entry

/// A unified entry on the timeline (task or calendar event)
struct TimelineEntry: Identifiable {
    enum EntryType { case task, calendarEvent }
    
    let id: UUID
    let type: EntryType
    let title: String
    let emoji: String?
    let startTime: Date
    let durationMinutes: Int
    let colorHex: String?
    let isDone: Bool
    let nudgeItem: NudgeItem?
    
    var endTime: Date {
        startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
    
    var color: Color {
        if let hex = colorHex { return Color(hex: hex) }
        return type == .calendarEvent ? Color(hex: "BF5AF2") : DesignTokens.accentActive
    }
}

// MARK: - Timeline View

struct TimelineView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var entries: [TimelineEntry] = []
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    // External calendar events injected by parent
    var calendarEvents: [TimelineEntry] = []
    
    // Callbacks
    var onTapTask: ((NudgeItem) -> Void)?
    
    // Timeline config
    private let hourHeight: CGFloat = 80
    private let startHour = 6   // 6 AM
    private let endHour = 23    // 11 PM
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid lines
                    hourGrid
                    
                    // Task blocks
                    ForEach(allEntries) { entry in
                        timelineBlock(for: entry)
                    }
                    
                    // "Now" indicator
                    nowIndicator
                }
                .frame(
                    width: nil,
                    height: CGFloat(endHour - startHour) * hourHeight
                )
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.top, DesignTokens.spacingSM)
                .padding(.bottom, 100)
                .id("timeline")
            }
            .onAppear {
                loadEntries()
                startTimer()
                scrollToNow(proxy: proxy)
            }
            .onDisappear { stopTimer() }
            .onReceive(NotificationCenter.default.publisher(for: .nudgeDataChanged)) { _ in
                loadEntries()
            }
        }
    }
    
    // MARK: - Combined Entries
    
    private var allEntries: [TimelineEntry] {
        (entries + calendarEvents).sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - Hour Grid
    
    private var hourGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
                    // Hour label
                    Text(formatHour(hour))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .frame(width: 44, alignment: .trailing)
                    
                    // Divider line
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 0.5)
                        .padding(.top, 7)
                }
                .frame(height: hourHeight)
            }
        }
    }
    
    // MARK: - Now Indicator
    
    private var nowIndicator: some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let totalMinutes = (hour - startHour) * 60 + minute
        let yOffset = CGFloat(totalMinutes) / 60.0 * hourHeight
        
        return HStack(spacing: 0) {
            Circle()
                .fill(DesignTokens.accentOverdue)
                .frame(width: 8, height: 8)
            
            Rectangle()
                .fill(DesignTokens.accentOverdue)
                .frame(height: 1.5)
        }
        .offset(x: 48, y: yOffset)
        .opacity(hour >= startHour && hour < endHour ? 1 : 0)
    }
    
    // MARK: - Timeline Block
    
    private func timelineBlock(for entry: TimelineEntry) -> some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: entry.startTime)
        let minute = calendar.component(.minute, from: entry.startTime)
        let totalMinutes = (hour - startHour) * 60 + minute
        let yOffset = CGFloat(totalMinutes) / 60.0 * hourHeight
        let blockHeight = max(CGFloat(entry.durationMinutes) / 60.0 * hourHeight, 36)
        
        return Button {
            if let item = entry.nudgeItem {
                onTapTask?(item)
            }
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                // Color bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(entry.color)
                    .frame(width: 3)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if let emoji = entry.emoji {
                            Text(emoji)
                                .font(.system(size: 13))
                        }
                        
                        Text(entry.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(
                                entry.isDone
                                    ? DesignTokens.textTertiary
                                    : DesignTokens.textPrimary
                            )
                            .strikethrough(entry.isDone)
                            .lineLimit(1)
                    }
                    
                    if entry.durationMinutes > 0 {
                        Text(String(localized: "\(entry.durationMinutes) min"))
                            .font(.system(size: 10))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                
                Spacer()
                
                if entry.isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.accentComplete)
                }
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, 4)
            .frame(height: blockHeight, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .fill(entry.color.opacity(entry.isDone ? 0.04 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .strokeBorder(entry.color.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .offset(x: 60, y: yOffset)
        .padding(.trailing, 60 + DesignTokens.spacingLG)
    }
    
    // MARK: - Data Loading
    
    private func loadEntries() {
        let repository = NudgeRepository(modelContext: modelContext)
        let active = repository.fetchActiveQueue()
        let done = repository.fetchCompletedToday()
        
        let allItems = (active + done).filter { $0.scheduledTime != nil }
        
        entries = allItems.compactMap { item -> TimelineEntry? in
            guard let scheduledTime = item.scheduledTime else { return nil }
            return TimelineEntry(
                id: item.id,
                type: .task,
                title: item.content,
                emoji: item.emoji,
                startTime: scheduledTime,
                durationMinutes: item.estimatedMinutes ?? 15,
                colorHex: item.categoryColorHex,
                isDone: item.status == .done,
                nudgeItem: item
            )
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                currentTime = Date()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func scrollToNow(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            proxy.scrollTo("timeline", anchor: .center)
        }
    }
    
    // MARK: - Formatting
    
    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12
        let ampm = hour >= 12 ? "PM" : "AM"
        return "\(h == 0 ? 12 : h) \(ampm)"
    }
}
