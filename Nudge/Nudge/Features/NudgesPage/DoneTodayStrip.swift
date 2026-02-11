//
//  DoneTodayStrip.swift
//  Nudge
//
//  A "trophy case" showing tasks completed today as a horizontal scroll of mini badges.
//  Celebrates what you've done without taking vertical space.
//  No-shame design: shows "Fresh start 🌅" for 0 tasks instead of empty.
//

import SwiftUI

struct DoneTodayStrip: View {
    
    let items: [NudgeItem]
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // Section header
                HStack(spacing: DesignTokens.spacingSM) {
                    Image(systemName: "trophy.fill")
                        .font(AppTheme.caption)
                        .foregroundStyle(DesignTokens.accentComplete)
                    
                    Text(String(localized: "Done today"))
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Text("\(items.count)")
                        .font(AppTheme.rounded(.caption, weight: .bold))
                        .foregroundStyle(DesignTokens.accentComplete)
                }
                .padding(.horizontal, DesignTokens.spacingSM)
                
                // Horizontal scroll of completed task badges
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingSM) {
                        ForEach(items, id: \.id) { item in
                            doneBadge(item)
                        }
                    }
                    .padding(.horizontal, DesignTokens.spacingSM)
                }
            }
            .padding(.vertical, DesignTokens.spacingMD)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusCard))
            .transition(.opacity)
        }
    }
    
    // MARK: - Done Badge
    
    private func doneBadge(_ item: NudgeItem) -> some View {
        HStack(spacing: 4) {
            // Emoji or checkmark
            if let emoji = item.emoji, !emoji.isEmpty {
                Image(systemName: TaskIconResolver.resolveSymbol(for: emoji))
                    .font(AppTheme.captionBold)
                    .foregroundStyle(DesignTokens.accentComplete)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppTheme.captionBold)
                    .foregroundStyle(DesignTokens.accentComplete)
            }
            
            Text(item.content)
                .font(AppTheme.caption)
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, DesignTokens.spacingSM + 2)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(DesignTokens.accentComplete.opacity(0.15))
                .overlay(
                    Capsule()
                        .strokeBorder(DesignTokens.accentComplete.opacity(0.3), lineWidth: 0.5)
                )
        }
        .nudgeAccessibility(
            label: String(localized: "Completed: \(item.content)"),
            hint: nil,
            traits: .isStaticText
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        DoneTodayStrip(items: [
            { let i = NudgeItem(content: "Buy groceries", emoji: "🛒", sortOrder: 1); i.markDone(); return i }(),
            { let i = NudgeItem(content: "Call doctor", emoji: "📞", sortOrder: 2); i.markDone(); return i }(),
            { let i = NudgeItem(content: "File taxes", emoji: "📊", sortOrder: 3); i.markDone(); return i }(),
        ])
        .padding()
    }
    .preferredColorScheme(.dark)
}
