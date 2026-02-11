//
//  SectionEmptyState.swift
//  Nudge
//
//  Contextual, ADHD-friendly empty states for time-horizon sections.
//
//  ADHD research backing:
//  • Empty ≠ failure. ADHD brains interpret blank screens as "I forgot something"
//    or "I'm failing" (Ramsay & Rostain, 2015). Explicit positive framing prevents
//    shame spirals.
//  • Time-of-day awareness matches the ADHD "now vs. not now" perception (Barkley, 2012).
//  • Minimal footprint — a single line, not a big card — avoids adding visual clutter.
//

import SwiftUI

// MARK: - Section Empty State

struct SectionEmptyState: View {
    
    let horizon: TimeHorizon
    let hasCompletedToday: Bool
    
    private var config: EmptyStateConfig {
        EmptyStateConfig.for(horizon: horizon, hasCompletedToday: hasCompletedToday)
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: config.emoji)
                .font(.system(size: 14))
                .foregroundStyle(config.textColor)
            
            Text(config.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(config.textColor)
            
            Spacer()
            
            if let action = config.action {
                Button {
                    action.perform()
                } label: {
                    Text(action.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentActive)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignTokens.spacingSM)
        .padding(.horizontal, DesignTokens.spacingMD)
        .nudgeAccessibility(
            label: config.accessibilityLabel,
            traits: .isStaticText
        )
    }
}

// MARK: - Configuration

private struct EmptyStateConfig {
    let emoji: String
    let message: String
    let textColor: Color
    let action: EmptyStateAction?
    let accessibilityLabel: String
    
    static func `for`(horizon: TimeHorizon, hasCompletedToday: Bool) -> EmptyStateConfig {
        switch horizon {
        case .today:
            if hasCompletedToday {
                // Completed everything — celebrate!
                return EmptyStateConfig(
                    emoji: "party.popper.fill",
                    message: String(localized: "You did it — enjoy the win"),
                    textColor: DesignTokens.accentComplete,
                    action: nil,
                    accessibilityLabel: String(localized: "All tasks for today are complete. Enjoy the win!")
                )
            } else {
                // Nothing scheduled yet
                return EmptyStateConfig(
                    emoji: "sun.max.fill",
                    message: String(localized: "Nothing for today yet"),
                    textColor: DesignTokens.textTertiary,
                    action: EmptyStateAction(
                        label: String(localized: "Add one"),
                        perform: {
                            NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
                        }
                    ),
                    accessibilityLabel: String(localized: "No tasks for today. Tap add one to create a task.")
                )
            }
            
        case .tomorrow:
            return EmptyStateConfig(
                emoji: "cloud.fill",
                message: String(localized: "Tomorrow's looking light"),
                textColor: DesignTokens.textTertiary,
                action: nil,
                accessibilityLabel: String(localized: "No tasks scheduled for tomorrow")
            )
            
        case .thisWeek:
            return EmptyStateConfig(
                emoji: "tray.fill",
                message: String(localized: "This week is clear"),
                textColor: DesignTokens.textTertiary,
                action: nil,
                accessibilityLabel: String(localized: "No tasks scheduled for this week")
            )
            
        case .later:
            return EmptyStateConfig(
                emoji: "beach.umbrella.fill",
                message: String(localized: "Nothing on the horizon"),
                textColor: DesignTokens.textTertiary,
                action: nil,
                accessibilityLabel: String(localized: "No tasks scheduled for later")
            )
            
        case .snoozed:
            return EmptyStateConfig(
                emoji: "alarm.fill",
                message: String(localized: "Nothing snoozed"),
                textColor: DesignTokens.textTertiary,
                action: nil,
                accessibilityLabel: String(localized: "No snoozed tasks")
            )
            
        case .doneToday:
            return EmptyStateConfig(
                emoji: "sunrise.fill",
                message: String(localized: "Fresh start — nothing done yet"),
                textColor: DesignTokens.textTertiary,
                action: nil,
                accessibilityLabel: String(localized: "No tasks completed today yet")
            )
        }
    }
}

// MARK: - Action

private struct EmptyStateAction {
    let label: String
    let perform: () -> Void
}

// MARK: - Which Sections Show Empty States

extension TimeHorizon {
    /// Whether this section should show an empty state message when it has no items.
    /// Only the primary horizons (Today, Tomorrow) show them — others just hide.
    /// Done Today only shows if there are active items (so the user sees the section exists).
    var showsEmptyState: Bool {
        switch self {
        case .today:     return true
        case .tomorrow:  return true
        case .thisWeek:  return false  // No noise for distant horizons
        case .later:     return false
        case .snoozed:   return false
        case .doneToday: return false
        }
    }
}

// MARK: - Preview

#Preview("Today — All Done") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            SectionEmptyState(horizon: .today, hasCompletedToday: true)
            SectionEmptyState(horizon: .today, hasCompletedToday: false)
            SectionEmptyState(horizon: .tomorrow, hasCompletedToday: false)
            SectionEmptyState(horizon: .doneToday, hasCompletedToday: false)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
