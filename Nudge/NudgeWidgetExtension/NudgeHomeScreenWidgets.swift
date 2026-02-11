//
//  NudgeHomeScreenWidgets.swift
//  NudgeWidgetExtension
//
//  Home Screen and Lock Screen widgets for Nudge.
//  Reads task data from the shared App Group store.
//
//  Widget families:
//    • .systemSmall   — Next task card (one card at a time, ADHD-friendly)
//    • .systemMedium  — Next task + daily progress ring
//    • .accessoryCircular — Progress ring for Lock Screen
//    • .accessoryRectangular — Next task + count for Lock Screen
//

import WidgetKit
import SwiftUI

// MARK: - Widget Data

/// Shared data structure for widget timeline entries.
struct NudgeWidgetEntry: TimelineEntry {
    let date: Date
    let nextTask: String?
    let nextTaskEmoji: String
    let nextTaskID: String?
    let activeCount: Int
    let completedToday: Int
    let totalToday: Int
    let isPlaceholder: Bool
    
    static var placeholder: NudgeWidgetEntry {
        NudgeWidgetEntry(
            date: .now,
            nextTask: "Call the dentist",
            nextTaskEmoji: "📞",
            nextTaskID: nil,
            activeCount: 3,
            completedToday: 2,
            totalToday: 5,
            isPlaceholder: true
        )
    }
    
    static var empty: NudgeWidgetEntry {
        NudgeWidgetEntry(
            date: .now,
            nextTask: nil,
            nextTaskEmoji: "🐧",
            nextTaskID: nil,
            activeCount: 0,
            completedToday: 0,
            totalToday: 0,
            isPlaceholder: false
        )
    }
}

// MARK: - Timeline Provider

struct NudgeWidgetProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> NudgeWidgetEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NudgeWidgetEntry) -> Void) {
        completion(readCurrentEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NudgeWidgetEntry>) -> Void) {
        let entry = readCurrentEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    /// Read task data from the shared App Group UserDefaults.
    /// The main app writes this data on every refresh via `syncWidgetData()`.
    private func readCurrentEntry() -> NudgeWidgetEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.tarsitgroup.nudge") else {
            return .empty
        }
        
        let nextTask = defaults.string(forKey: "widget_nextTask")
        let nextTaskEmoji = defaults.string(forKey: "widget_nextTaskEmoji") ?? "🐧"
        let nextTaskID = defaults.string(forKey: "widget_nextTaskID")
        let activeCount = defaults.integer(forKey: "widget_activeCount")
        let completedToday = defaults.integer(forKey: "widget_completedToday")
        let totalToday = defaults.integer(forKey: "widget_totalToday")
        
        return NudgeWidgetEntry(
            date: .now,
            nextTask: nextTask,
            nextTaskEmoji: nextTaskEmoji,
            nextTaskID: nextTaskID,
            activeCount: activeCount,
            completedToday: completedToday,
            totalToday: totalToday,
            isPlaceholder: false
        )
    }
}

// MARK: - Home Screen Widget (Small)

/// Shows the next task — one card at a time, true to Nudge's ADHD philosophy.
struct NudgeSmallWidgetView: View {
    let entry: NudgeWidgetEntry
    
    var body: some View {
        if let task = entry.nextTask {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(entry.nextTaskEmoji)
                        .font(.system(size: 20))
                    Spacer()
                    Text("\(entry.activeCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                
                Spacer()
                
                Text(task)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                
                Text("up next")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.black)
            .widgetURL(URL(string: "nudge://viewTask?id=\(entry.nextTaskID ?? "")"))
        } else {
            // Empty state — all clear
            VStack(spacing: 8) {
                Text("🐧")
                    .font(.system(size: 32))
                Text("all clear")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .widgetURL(URL(string: "nudge://allItems"))
        }
    }
}

// MARK: - Home Screen Widget (Medium)

/// Shows next task + daily progress ring.
struct NudgeMediumWidgetView: View {
    let entry: NudgeWidgetEntry
    
    private var progress: Double {
        guard entry.totalToday > 0 else { return 0 }
        return Double(entry.completedToday) / Double(entry.totalToday)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Next task
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(entry.nextTaskEmoji)
                        .font(.system(size: 20))
                    Text("up next")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let task = entry.nextTask {
                    Text(task)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                } else {
                    Text("queue clear 🎉")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                if entry.activeCount > 0 {
                    Text("\(entry.activeCount) remaining")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(hex: "30D158"),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(entry.completedToday)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/\(entry.totalToday)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .widgetURL(URL(string: "nudge://allItems"))
    }
}

// MARK: - Lock Screen Widget (Circular)

/// Progress ring for the Lock Screen.
struct NudgeCircularWidgetView: View {
    let entry: NudgeWidgetEntry
    
    private var progress: Double {
        guard entry.totalToday > 0 else { return 0 }
        return Double(entry.completedToday) / Double(entry.totalToday)
    }
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            Gauge(value: progress) {
                Text("🐧")
                    .font(.system(size: 14))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.green)
        }
        .widgetURL(URL(string: "nudge://allItems"))
    }
}

// MARK: - Lock Screen Widget (Rectangular)

/// Next task + count for the Lock Screen.
struct NudgeRectangularWidgetView: View {
    let entry: NudgeWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("🐧")
                    .font(.system(size: 10))
                Text("NUDGE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.activeCount) left")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            if let task = entry.nextTask {
                Text(task)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
            } else {
                Text("all clear")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "nudge://allItems"))
    }
}

// MARK: - Widget Configurations

struct NudgeHomeWidget: Widget {
    let kind: String = "NudgeHomeWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NudgeWidgetProvider()) { entry in
            Group {
                switch entry.widgetFamily {
                case .systemSmall:
                    NudgeSmallWidgetView(entry: entry)
                case .systemMedium:
                    NudgeMediumWidgetView(entry: entry)
                default:
                    NudgeSmallWidgetView(entry: entry)
                }
            }
            .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Nudge")
        .description("Your next task at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NudgeLockScreenWidget: Widget {
    let kind: String = "NudgeLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NudgeWidgetProvider()) { entry in
            Group {
                switch entry.widgetFamily {
                case .accessoryCircular:
                    NudgeCircularWidgetView(entry: entry)
                case .accessoryRectangular:
                    NudgeRectangularWidgetView(entry: entry)
                default:
                    NudgeCircularWidgetView(entry: entry)
                }
            }
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Nudge")
        .description("Task progress on your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget Family Helper

private extension NudgeWidgetEntry {
    @Environment(\.widgetFamily) var widgetFamily
}

```