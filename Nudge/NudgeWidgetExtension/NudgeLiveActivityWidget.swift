//
//  NudgeLiveActivityWidget.swift
//  NudgeWidgetExtension
//
//  ActivityConfiguration that renders the Live Activity on
//  Lock Screen and Dynamic Island. Uses views defined in the
//  shared NudgeLiveActivity.swift.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes (must match main app)

struct NudgeActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        var taskContent: String
        var taskEmoji: String
        var queuePosition: Int
        var queueTotal: Int
        var accentColorHex: String
        var timeOfDayIndex: Int
        var taskID: String          // Item UUID for deep links
        var startedAt: Date         // When this task became active (for timer)
    }
    
    var startedAt: Date
}

// MARK: - Time of Day (must match main app)

enum TimeOfDay: Int, CaseIterable {
    case dawn     = 0
    case morning  = 1
    case afternoon = 2
    case sunset   = 3
    case night    = 4
    
    var color: Color {
        switch self {
        case .dawn:      return Color(hex: "5B86E5")
        case .morning:   return Color(hex: "FFD700")
        case .afternoon: return Color(hex: "FF9F0A")
        case .sunset:    return Color(hex: "FF6B35")
        case .night:     return Color(hex: "4A00E0")
        }
    }
}

// MARK: - Color(hex:) Extension (widget-local, no dependency on main app)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 3:
            r = Double((int >> 8) * 17) / 255.0
            g = Double((int >> 4 & 0xF) * 17) / 255.0
            b = Double((int & 0xF) * 17) / 255.0
        case 6:
            r = Double(int >> 16) / 255.0
            g = Double(int >> 8 & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Live Activity Widget

struct NudgeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NudgeActivityAttributes.self) { context in
            // Lock Screen / Notification banner presentation
            NudgeLockScreenView(state: context.state)
                .padding(.vertical, 8)
                .widgetURL(URL(string: "nudge://viewTask?id=\(context.state.taskID)"))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    VStack(spacing: 4) {
                        Image(systemName: WidgetIconResolver.symbol(for: context.state.taskEmoji))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(hex: context.state.accentColorHex))
                        
                        // Live timer
                        Text(context.state.startedAt, style: .timer)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.queuePosition)/\(context.state.queueTotal)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.taskContent)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                        .foregroundStyle(.white)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Time-of-day gradient strip
                        HStack(spacing: 2) {
                            ForEach(TimeOfDay.allCases, id: \.rawValue) { timeOfDay in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(timeOfDay.color)
                                    .frame(height: 3)
                                    .opacity(timeOfDay.rawValue == context.state.timeOfDayIndex ? 1.0 : 0.25)
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Link(destination: URL(string: "nudge://markDone?id=\(context.state.taskID)")!) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Done")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(Color(hex: "30D158"))
                                )
                            }
                            
                            Link(destination: URL(string: "nudge://snooze?id=\(context.state.taskID)")!) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("Snooze")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(Color.white.opacity(0.15))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: WidgetIconResolver.symbol(for: context.state.taskEmoji))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: context.state.accentColorHex))
            } compactTrailing: {
                // Live timer in compact trailing
                Text(context.state.startedAt, style: .timer)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: WidgetIconResolver.symbol(for: context.state.taskEmoji))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: context.state.accentColorHex))
            }
            .widgetURL(URL(string: "nudge://viewTask?id=\(context.state.taskID)"))
        }
    }
}

// MARK: - Lock Screen View

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
            
            // Task content + timer
            HStack(spacing: 12) {
                Image(systemName: WidgetIconResolver.symbol(for: state.taskEmoji))
                    .font(.system(size: 22, weight: .semibold))
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
                        
                        // Live timer
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
            
            // Action buttons
            HStack(spacing: 12) {
                Link(destination: URL(string: "nudge://markDone?id=\(state.taskID)")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "30D158"))
                    )
                }
                
                Link(destination: URL(string: "nudge://snooze?id=\(state.taskID)")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 13))
                        Text("Snooze")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.15))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .activityBackgroundTint(Color.black)
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: NudgeActivityAttributes(startedAt: .now)) {
    NudgeLiveActivityWidget()
} contentStates: {
    NudgeActivityAttributes.ContentState(
        taskContent: "Call the dentist",
        taskEmoji: "📞",
        queuePosition: 1,
        queueTotal: 3,
        accentColorHex: "007AFF",
        timeOfDayIndex: 2,
        taskID: UUID().uuidString,
        startedAt: .now
    )
}

// MARK: - Widget-local Emoji → SF Symbol Resolver

private enum WidgetIconResolver {
    static func symbol(for emoji: String) -> String {
        switch emoji {
        case "📞": return "phone.fill"
        case "📱": return "iphone"
        case "💬": return "message.fill"
        case "📧", "✉️": return "envelope.fill"
        case "📬": return "envelope.open.fill"
        case "🎂": return "gift.fill"
        case "💊": return "pills.fill"
        case "🏥": return "cross.case.fill"
        case "🦷": return "mouth.fill"
        case "🧘": return "figure.mind.and.body"
        case "🏋️", "🏋️‍♂️", "🏋️‍♀️": return "dumbbell.fill"
        case "🪴", "🌱": return "leaf.fill"
        case "🧹": return "sparkles"
        case "🐶", "🐕", "🐾": return "pawprint.fill"
        case "📋": return "checklist"
        case "📊": return "chart.bar.fill"
        case "📝": return "doc.text.fill"
        case "✍️": return "pencil.line"
        case "📌": return "pin.fill"
        case "🗓️", "📅": return "calendar"
        case "💰": return "dollarsign.circle.fill"
        case "📖": return "book.fill"
        case "🎬": return "play.rectangle.fill"
        case "🎸": return "guitars.fill"
        case "🎙️": return "mic.fill"
        case "✈️": return "airplane"
        case "🏖️": return "beach.umbrella.fill"
        case "📦": return "shippingbox.fill"
        case "🔍": return "magnifyingglass"
        case "🎯": return "target"
        case "🥗": return "fork.knife"
        case "🛒": return "cart.fill"
        case "💼": return "briefcase.fill"
        case "🧾": return "doc.text.fill"
        default: return "checklist"
        }
    }
}
