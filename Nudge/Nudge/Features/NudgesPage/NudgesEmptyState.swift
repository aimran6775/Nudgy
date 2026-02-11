//
//  NudgesEmptyState.swift
//  Nudge
//
//  Empty state for the Nudges page.
//  Three variants:
//  1. All clear (🐋 Whale catch!) — last task completed, celebrate
//  2. All snoozed — tasks sleeping, offer to wake one
//  3. Zero tasks — fresh start, invite brain dump or quick add
//
//  ADHD design: never a blank white screen. Nudgy always has something to say.
//

import SwiftUI

struct NudgesEmptyState: View {
    
    let variant: EmptyVariant
    let snoozedCount: Int
    let lastSnowflakesEarned: Int
    
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum EmptyVariant {
        case allClear       // Just finished everything
        case allSnoozed     // Tasks exist but all sleeping
        case noTasks        // Nothing at all
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()
            
            switch variant {
            case .allClear:
                allClearView
            case .allSnoozed:
                allSnoozedView
            case .noTasks:
                noTasksView
            }
            
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
    
    // MARK: - All Clear (Whale Catch!)
    
    private var allClearView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            // Whale emoji — big celebration
            Text("🐋")
                .font(AppTheme.emoji(size: 64))
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text(String(localized: "All clear!"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(String(localized: "You've caught a rare whale · +15❄️"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.goldCurrency)
            }
            
            // Action buttons
            HStack(spacing: DesignTokens.spacingMD) {
                Button {
                    NotificationCenter.default.post(name: .nudgeOpenChat, object: nil)
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "bubble.left.fill")
                        Text(String(localized: "Feed Nudgy 🐧"))
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background {
                        Capsule().fill(DesignTokens.accentComplete.opacity(0.2))
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                
                Button {
                    NotificationCenter.default.post(name: .nudgeOpenBrainDump, object: nil)
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "brain.fill")
                        Text(String(localized: "Brain Dump"))
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.accentActive)
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background {
                        Capsule().fill(DesignTokens.accentActive.opacity(0.08))
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - All Snoozed
    
    private var allSnoozedView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            PenguinSceneView(
                size: .medium,
                expressionOverride: .sleeping,
                accentColorOverride: DesignTokens.textTertiary
            )
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text(String(localized: "Everything's sleeping 💤"))
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(snoozedCount == 1
                     ? String(localized: "1 task snoozed. Want to wake it up?")
                     : String(localized: "\(snoozedCount) tasks snoozed. Want to wake one up?"))
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: DesignTokens.spacingMD) {
                Button {
                    NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "plus.circle.fill")
                        Text(String(localized: "Add New"))
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background {
                        Capsule().fill(DesignTokens.accentActive.opacity(0.2))
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - No Tasks (Fresh Start)
    
    private var noTasksView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            PenguinSceneView(
                size: .large,
                expressionOverride: emptyViewExpression,
                accentColorOverride: DesignTokens.textTertiary
            )
            
            VStack(spacing: DesignTokens.spacingSM) {
                Text(emptyViewTitle)
                    .font(AppTheme.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(emptyViewSubtitle)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.spacingXL)
            }
            
            HStack(spacing: DesignTokens.spacingMD) {
                Button {
                    NotificationCenter.default.post(name: .nudgeOpenChat, object: nil)
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: "bubble.left.fill")
                        Text(String(localized: "Talk to Nudgy"))
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.spacingXL)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background {
                        Capsule().fill(DesignTokens.accentActive.opacity(0.2))
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                
                Button {
                    NotificationCenter.default.post(name: .nudgeOpenQuickAdd, object: nil)
                } label: {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "plus")
                        Text(String(localized: "Add"))
                    }
                    .font(AppTheme.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.accentActive)
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background {
                        Capsule().fill(DesignTokens.accentActive.opacity(0.08))
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Time-Aware Helpers
    
    private enum DayPeriod {
        case morning, afternoon, evening, night
        
        static var current: DayPeriod {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12:  return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default:      return .night
            }
        }
    }
    
    private var emptyViewExpression: PenguinExpression {
        switch DayPeriod.current {
        case .morning:   return .idle
        case .afternoon: return .thinking
        case .evening:   return .idle
        case .night:     return .sleeping
        }
    }
    
    private var emptyViewTitle: String {
        switch DayPeriod.current {
        case .morning:   return String(localized: "Good morning! 🌅")
        case .afternoon: return String(localized: "Quiet afternoon 🌤️")
        case .evening:   return String(localized: "Winding down 🌙")
        case .night:     return String(localized: "Nothing on your plate 🐧")
        }
    }
    
    private var emptyViewSubtitle: String {
        switch DayPeriod.current {
        case .morning:
            return String(localized: "No nudges yet — tell Nudgy what's on your mind, or add one yourself")
        case .afternoon:
            return String(localized: "Your list is clear. Unload something, or enjoy the quiet")
        case .evening:
            return String(localized: "Nothing pending. Prep tomorrow, or just relax — you've earned it")
        case .night:
            return String(localized: "Nothing pending. Nudgy's here if you remember something")
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        NudgesEmptyState(
            variant: .allClear,
            snoozedCount: 0,
            lastSnowflakesEarned: 15
        )
    }
    .preferredColorScheme(.dark)
}
