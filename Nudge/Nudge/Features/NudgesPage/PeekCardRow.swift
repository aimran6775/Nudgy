//
//  PeekCardRow.swift
//  Nudge
//
//  A compact "up next" row showing one upcoming task with its fish bounty.
//  These sit below the hero card as a preview of what's coming.
//  Tappable to promote to hero card.
//

import SwiftUI

struct PeekCardRow: View {
    
    let item: NudgeItem
    let streak: Int
    var onTap: () -> Void = {}
    
    private var accentColor: Color {
        AccentColorSystem.shared.color(for: item.accentStatus)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.spacingMD) {
                // Task icon
                TaskIconView(
                    emoji: item.emoji,
                    actionType: item.actionType,
                    size: .small,
                    accentColor: accentColor
                )
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.content)
                        .font(AppTheme.footnote.weight(.medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(1)
                    
                    // Subtitle: contact or duration or stale
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(AppTheme.caption)
                            .foregroundStyle(subtitleColor)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Fish bounty (compact)
                FishBountyLabel(item: item, streak: streak, compact: true)
            }
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM + 2)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .fill(accentColor.opacity(0.03))
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: item.content,
            hint: String(localized: "Tap to make this your current task"),
            traits: .isButton
        )
    }
    
    // MARK: - Subtitle Logic
    
    private var subtitleText: String? {
        if let contact = item.contactName, !contact.isEmpty {
            return contact
        }
        if item.isStale {
            return String(localized: "\(item.ageInDays) days old")
        }
        if let label = item.durationLabel {
            return label
        }
        if let actionType = item.actionType {
            return actionType.label
        }
        return nil
    }
    
    private var subtitleColor: Color {
        if item.isStale { return DesignTokens.accentStale }
        return DesignTokens.textTertiary
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 8) {
            PeekCardRow(
                item: NudgeItem(content: "Text Sarah about Saturday plans", emoji: "💬", actionType: .text, contactName: "Sarah", sortOrder: 1),
                streak: 3
            )
            PeekCardRow(
                item: NudgeItem(content: "Buy groceries for the week", emoji: "🛒", sortOrder: 2),
                streak: 0
            )
            PeekCardRow(
                item: {
                    let item = NudgeItem(content: "File expense report from last month", emoji: "📊", sortOrder: 3)
                    // Simulate stale
                    return item
                }(),
                streak: 5
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
