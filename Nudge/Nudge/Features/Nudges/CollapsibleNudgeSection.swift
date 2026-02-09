//
//  CollapsibleNudgeSection.swift
//  Nudge
//
//  A collapsible section container for the Nudges page.
//  ADHD-optimized: "Today" is always expanded, future horizons are collapsed
//  by default to prevent visual overwhelm (Cowan, 2001; Schwartz, 2004).
//
//  Uses smooth spring animation and persists expand/collapse state per session.
//

import SwiftUI

// MARK: - Collapsible Section

struct CollapsibleNudgeSection<Content: View>: View {
    
    let horizon: TimeHorizon
    let count: Int
    let accentColor: Color
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable header
            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
                HapticService.shared.prepare()
            } label: {
                sectionHeader
            }
            .buttonStyle(.plain)
            
            // Expandable content
            if isExpanded {
                VStack(spacing: DesignTokens.spacingSM) {
                    content()
                }
                .padding(.top, DesignTokens.spacingSM)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).animation(.easeOut(duration: 0.2)),
                        removal: .opacity.animation(.easeIn(duration: 0.15))
                    )
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var sectionHeader: some View {
        HStack(spacing: DesignTokens.spacingSM) {
            // Icon
            Image(systemName: horizon.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 20)
            
            // Title
            Text(horizon.title)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
                .textCase(.uppercase)
            
            // Count badge
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(0.12))
                )
            
            Spacer()
            
            // Expand/collapse chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        }
        .padding(.horizontal, DesignTokens.spacingXS)
        .padding(.vertical, DesignTokens.spacingXS)
        .contentShape(Rectangle())
        .nudgeAccessibility(
            label: "\(horizon.title), \(count) items",
            hint: isExpanded
                ? String(localized: "Double-tap to collapse")
                : String(localized: "Double-tap to expand"),
            traits: .isButton
        )
    }
}

// MARK: - Accent Color Mapping

extension TimeHorizon {
    /// The accent color for this horizon's header.
    var accentColor: Color {
        switch self {
        case .today:     return DesignTokens.accentActive
        case .tomorrow:  return Color(hex: "5E5CE6") // Indigo — calm future
        case .thisWeek:  return DesignTokens.textSecondary
        case .later:     return DesignTokens.textTertiary
        case .snoozed:   return DesignTokens.accentStale
        case .doneToday: return DesignTokens.accentComplete
        }
    }
}
