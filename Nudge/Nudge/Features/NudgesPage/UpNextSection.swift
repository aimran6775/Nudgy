//
//  UpNextSection.swift
//  Nudge
//
//  Shows 2-3 "up next" peek cards below the hero card.
//  These preview upcoming tasks with their fish bounties,
//  creating a "what's next" pull that motivates completing the current card.
//
//  Tap any card to promote it to hero position.
//

import SwiftUI

struct UpNextSection: View {
    
    let items: [NudgeItem]
    let streak: Int
    let onPromote: (NudgeItem) -> Void
    
    /// Show at most 3 peek cards
    private var visibleItems: [NudgeItem] {
        Array(items.prefix(3))
    }
    
    var body: some View {
        if !visibleItems.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // Section header
                HStack(spacing: DesignTokens.spacingSM) {
                    Text(String(localized: "Up next"))
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    if items.count > 3 {
                        Text(String(localized: "+\(items.count - 3) more"))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingXS)
                
                // Peek cards
                ForEach(visibleItems, id: \.id) { item in
                    PeekCardRow(
                        item: item,
                        streak: streak,
                        onTap: { onPromote(item) }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        UpNextSection(
            items: [
                NudgeItem(content: "Text Sarah about Saturday", emoji: "💬", actionType: .text, contactName: "Sarah", sortOrder: 1),
                NudgeItem(content: "Buy dog food", emoji: "🐶", sortOrder: 2),
                NudgeItem(content: "Email landlord about lease", emoji: "📧", actionType: .email, sortOrder: 3),
                NudgeItem(content: "Clean kitchen", emoji: "🧹", sortOrder: 4),
            ],
            streak: 3,
            onPromote: { _ in }
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
