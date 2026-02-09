//
//  DailyProgressHeader.swift
//  Nudge
//
//  A gentle progress indicator for the top of the Nudges page.
//  Shows "X of Y done today" with an animated ring.
//
//  ADHD research backing:
//  • Immediate visual feedback normalizes dopamine deficits (Volkow et al., 2009)
//  • Framing as progress (not deficit) avoids shame spirals (Ramsay & Rostain, 2015)
//  • No punishment for 0% days — just "Fresh start" messaging
//

import SwiftUI

// MARK: - Daily Progress Header

struct DailyProgressHeader: View {
    
    let completedToday: Int
    let totalToday: Int
    let streak: Int
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var progress: Double {
        guard totalToday > 0 else { return 0 }
        return min(1.0, Double(completedToday) / Double(totalToday))
    }
    
    private var isAllDone: Bool {
        totalToday > 0 && completedToday >= totalToday
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.spacingMD) {
            // Progress ring
            progressRing
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                progressLabel
                subtitleLabel
            }
            
            Spacer()
            
            // Streak badge (if active)
            if streak > 1 {
                streakBadge
            }
        }
        .padding(DesignTokens.spacingMD)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .fill(DesignTokens.cardSurface.opacity(0.3))
                
                // Subtle accent glow when all done
                if isAllDone {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.accentComplete.opacity(0.06), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                    .strokeBorder(
                        (isAllDone ? DesignTokens.accentComplete : Color.white).opacity(0.06),
                        lineWidth: 0.5
                    )
            }
        }
        .nudgeAccessibility(
            label: progressAccessibilityLabel,
            traits: .isStaticText
        )
    }
    
    // MARK: - Progress Ring
    
    private var progressRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 3)
            
            // Fill
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isAllDone ? DesignTokens.accentComplete : DesignTokens.accentActive,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8),
                    value: progress
                )
            
            // Center text
            if isAllDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignTokens.accentComplete)
            } else {
                Text("\(completedToday)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignTokens.textPrimary)
            }
        }
        .frame(width: 32, height: 32)
    }
    
    // MARK: - Labels
    
    private var progressLabel: some View {
        Group {
            if totalToday == 0 {
                Text(String(localized: "No tasks for today"))
                    .font(AppTheme.body.weight(.medium))
                    .foregroundStyle(DesignTokens.textSecondary)
            } else if isAllDone {
                Text(String(localized: "All done today! ✨"))
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.accentComplete)
            } else {
                Text(String(localized: "\(completedToday) of \(totalToday) done"))
                    .font(AppTheme.body.weight(.medium))
                    .foregroundStyle(DesignTokens.textPrimary)
            }
        }
    }
    
    private var subtitleLabel: some View {
        Group {
            if isAllDone {
                Text(String(localized: "You crushed it 🐧"))
                    .font(AppTheme.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
            } else if totalToday == 0 {
                Text(String(localized: "Fresh start 🌅"))
                    .font(AppTheme.footnote)
                    .foregroundStyle(DesignTokens.textTertiary)
            } else {
                let remaining = totalToday - completedToday
                Text(String(localized: "\(remaining) to go — you got this"))
                    .font(AppTheme.footnote)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
    }
    
    // MARK: - Streak
    
    private var streakBadge: some View {
        HStack(spacing: 3) {
            Text("🔥")
                .font(.system(size: 13))
            Text("\(streak)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(DesignTokens.accentStale)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(DesignTokens.accentStale.opacity(0.1))
        )
    }
    
    // MARK: - Accessibility
    
    private var progressAccessibilityLabel: String {
        if isAllDone {
            return String(localized: "All \(totalToday) tasks done today. \(streak) day streak.")
        } else if totalToday == 0 {
            return String(localized: "No tasks for today.")
        } else {
            return String(localized: "\(completedToday) of \(totalToday) tasks done today. \(streak) day streak.")
        }
    }
}

// MARK: - Preview

#Preview("Progress — In Progress") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            DailyProgressHeader(completedToday: 2, totalToday: 5, streak: 4)
            DailyProgressHeader(completedToday: 5, totalToday: 5, streak: 7)
            DailyProgressHeader(completedToday: 0, totalToday: 3, streak: 0)
            DailyProgressHeader(completedToday: 0, totalToday: 0, streak: 1)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
