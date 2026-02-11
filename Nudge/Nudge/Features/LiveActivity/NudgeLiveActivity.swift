//
//  NudgeLiveActivity.swift
//  Nudge
//
//  Live Activity + Dynamic Island — shows current task on Lock Screen.
//  Opt-in only (Settings toggle). Auto-restarts after 8-hour expiry.
//

import ActivityKit
import SwiftUI
import WidgetKit
import os.log

private let liveActivityLog = Logger(subsystem: "com.tarsitgroup.nudge", category: "LiveActivity")

// MARK: - Activity Attributes

struct NudgeActivityAttributes: ActivityAttributes {
    
    /// Static data — doesn't change during the activity lifetime
    public struct ContentState: Codable, Hashable {
        var taskContent: String
        var taskEmoji: String
        var queuePosition: Int      // e.g. 2 (of 5)
        var queueTotal: Int         // e.g. 5
        var accentColorHex: String  // Status-driven accent
        var timeOfDayIndex: Int     // 0-4 for gradient strip
        var taskID: String          // Item UUID for deep link actions
        var startedAt: Date         // When this task became active (for live timer)
    }
    
    /// Fixed at activity start
    var startedAt: Date
}

// MARK: - Time of Day

enum TimeOfDay: Int, CaseIterable {
    case dawn     = 0  // 5am-8am
    case morning  = 1  // 8am-12pm
    case afternoon = 2 // 12pm-5pm
    case sunset   = 3  // 5pm-8pm
    case night    = 4  // 8pm-5am
    
    var color: Color {
        switch self {
        case .dawn:      return Color(hex: "5B86E5")  // Cool blue
        case .morning:   return Color(hex: "FFD700")  // Gold
        case .afternoon: return Color(hex: "FF9F0A")  // Amber
        case .sunset:    return Color(hex: "FF6B35")  // Orange-red
        case .night:     return Color(hex: "4A00E0")  // Indigo
        }
    }
    
    static func current(for date: Date = .now) -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<8:   return .dawn
        case 8..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<20: return .sunset
        default:      return .night
        }
    }
}

// MARK: - Live Activity Manager

@MainActor @Observable
final class LiveActivityManager {
    
    static let shared = LiveActivityManager()
    
    private(set) var currentActivity: Activity<NudgeActivityAttributes>?
    private(set) var isRunning = false
    
    // MARK: - Start
    
    /// Start a Live Activity for the given task.
    func start(
        taskContent: String,
        taskEmoji: String,
        queuePosition: Int,
        queueTotal: Int,
        accentHex: String,
        taskID: String = ""
    ) {
        liveActivityLog.info("start() called — task: \(taskContent), taskID: \(taskID)")
        liveActivityLog.info("areActivitiesEnabled: \(ActivityAuthorizationInfo().areActivitiesEnabled)")
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            liveActivityLog.warning("Live Activities not enabled by system")
            return
        }
        
        // End any existing activity first
        Task { await endAll() }
        
        let now = Date.now
        let attributes = NudgeActivityAttributes(startedAt: now)
        let state = NudgeActivityAttributes.ContentState(
            taskContent: taskContent,
            taskEmoji: taskEmoji,
            queuePosition: queuePosition,
            queueTotal: queueTotal,
            accentColorHex: accentHex,
            timeOfDayIndex: TimeOfDay.current().rawValue,
            taskID: taskID,
            startedAt: now
        )
        
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(7.5 * 3600))
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            isRunning = true
            liveActivityLog.info("Live Activity started! ID: \(self.currentActivity?.id ?? "nil")")
        } catch {
            liveActivityLog.error("Failed to start Live Activity: \(error)")
        }
    }
    
    // MARK: - Update
    
    /// Update the Live Activity with a new task.
    func update(
        taskContent: String,
        taskEmoji: String,
        queuePosition: Int,
        queueTotal: Int,
        accentHex: String,
        taskID: String = ""
    ) async {
        guard let activity = currentActivity else { return }
        
        // If the task changed, reset the timer. Otherwise keep existing.
        let isNewTask = activity.content.state.taskID != taskID
        let timerStart = isNewTask ? Date.now : activity.content.state.startedAt
        
        let state = NudgeActivityAttributes.ContentState(
            taskContent: taskContent,
            taskEmoji: taskEmoji,
            queuePosition: queuePosition,
            queueTotal: queueTotal,
            accentColorHex: accentHex,
            timeOfDayIndex: TimeOfDay.current().rawValue,
            taskID: taskID,
            startedAt: timerStart
        )
        
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(7.5 * 3600))
        await activity.update(content)
    }
    
    /// Update just the time-of-day gradient strip (called by background refresh).
    func updateTimeOfDay() async {
        guard let activity = currentActivity else { return }
        
        // Re-use existing state but update time index
        var state = activity.content.state
        state.timeOfDayIndex = TimeOfDay.current().rawValue
        
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(7.5 * 3600))
        await activity.update(content)
    }
    
    // MARK: - End
    
    /// End all Live Activities.
    func endAll() async {
        for activity in Activity<NudgeActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        isRunning = false
    }
    
    /// End activity when queue is empty.
    func endIfEmpty() async {
        await endAll()
    }
}

// MARK: - Live Activity Widget Views

/// Lock Screen presentation of the Live Activity.
struct NudgeLockScreenView: View {
    let state: NudgeActivityAttributes.ContentState
    
    var body: some View {
        VStack(spacing: 8) {
            // Time-of-day gradient strip
            HStack(spacing: 2) {
                ForEach(TimeOfDay.allCases, id: \.rawValue) { timeOfDay in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(timeOfDay.color)
                        .frame(height: 4)
                        .opacity(timeOfDay.rawValue == state.timeOfDayIndex ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, 16)
            
            // Task content + live timer
            HStack(spacing: 12) {
                Image(systemName: TaskIconResolver.resolveSymbol(for: state.taskEmoji))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(hex: state.accentColorHex))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.taskContent)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text("\(state.queuePosition) of \(state.queueTotal)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 3) {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                            Text(state.startedAt, style: .timer)
                                .font(.system(size: 12, design: .monospaced))
                                .monospacedDigit()
                        }
                        .foregroundStyle(Color(hex: state.accentColorHex))
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .activityBackgroundTint(Color.black)
    }
}

/// Compact Dynamic Island view.
struct NudgeCompactLeadingView: View {
    let state: NudgeActivityAttributes.ContentState
    
    var body: some View {
        Image(systemName: TaskIconResolver.resolveSymbol(for: state.taskEmoji))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
    }
}

struct NudgeCompactTrailingView: View {
    let state: NudgeActivityAttributes.ContentState
    
    var body: some View {
        Text(state.taskContent)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(.white)
    }
}

/// Expanded Dynamic Island view.
struct NudgeExpandedView: View {
    let state: NudgeActivityAttributes.ContentState
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: TaskIconResolver.resolveSymbol(for: state.taskEmoji))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(hex: state.accentColorHex))
                
                Text(state.taskContent)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Spacer()
            }
            
            // Time strip
            HStack(spacing: 2) {
                ForEach(TimeOfDay.allCases, id: \.rawValue) { timeOfDay in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(timeOfDay.color)
                        .frame(height: 3)
                        .opacity(timeOfDay.rawValue == state.timeOfDayIndex ? 1.0 : 0.25)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
