//
//  PileCountRow.swift
//  Nudge
//
//  Shows the count of remaining tasks beyond what's visible (hero + up next).
//  Tappable to expand an inline list of all remaining items.
//
//  "12 more in your pile" → tap → inline expansion of compact rows
//  At no point does the user leave the page.
//

import SwiftUI

struct PileCountRow: View {
    
    let items: [NudgeItem]
    let streak: Int
    let onDone: (NudgeItem) -> Void
    let onSnooze: (NudgeItem) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Tap target — pile count
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                    HapticService.shared.prepare()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: isExpanded ? "tray.full.fill" : "tray.fill")
                            .font(AppTheme.footnote)
                            .foregroundStyle(DesignTokens.textTertiary)
                        
                        Text(pileLabel)
                            .font(AppTheme.footnote.weight(.medium))
                            .foregroundStyle(DesignTokens.textSecondary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(AppTheme.captionBold)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingSM + 2)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .fill(Color.white.opacity(0.03))
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
                }
                .buttonStyle(.plain)
                .nudgeAccessibility(
                    label: pileLabel,
                    hint: String(localized: "Tap to see all remaining tasks"),
                    traits: .isButton
                )
                
                // Expanded inline list
                if isExpanded {
                    VStack(spacing: DesignTokens.spacingXS) {
                        ForEach(items, id: \.id) { item in
                            pileItemRow(item)
                        }
                    }
                    .padding(.top, DesignTokens.spacingSM)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
        }
    }
    
    // MARK: - Pile Label
    
    private var pileLabel: String {
        if items.count == 1 {
            return String(localized: "1 more in your pile")
        }
        return String(localized: "\(items.count) more in your pile")
    }
    
    // MARK: - Pile Item Row
    
    private func pileItemRow(_ item: NudgeItem) -> some View {
        let accentColor = AccentColorSystem.shared.color(for: item.accentStatus)
        
        return SwipeableRow(
            content: {
                HStack(spacing: DesignTokens.spacingSM) {
                    TaskIconView(
                        emoji: item.emoji,
                        actionType: item.actionType,
                        size: .small,
                        accentColor: accentColor
                    )
                    
                    Text(item.content)
                        .font(AppTheme.footnote.weight(.medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                    
                    // Compact bounty
                    FishBountyLabel(item: item, streak: streak, compact: true)
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .background {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                        .fill(Color.white.opacity(0.02))
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DesignTokens.cornerRadiusChip))
            },
            onSwipeLeading: { onDone(item) },
            leadingLabel: String(localized: "Done"),
            leadingIcon: "checkmark",
            leadingColor: DesignTokens.accentComplete,
            onSwipeTrailing: { onSnooze(item) },
            trailingLabel: String(localized: "Snooze"),
            trailingIcon: "moon.zzz.fill",
            trailingColor: DesignTokens.accentStale
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PileCountRow(
            items: [
                NudgeItem(content: "Clean the bathroom", emoji: "🧹", sortOrder: 5),
                NudgeItem(content: "Schedule dentist appointment", emoji: "🦷", sortOrder: 6),
                NudgeItem(content: "Research vacation spots", emoji: "✈️", sortOrder: 7),
                NudgeItem(content: "Return library books", emoji: "📚", sortOrder: 8),
            ],
            streak: 3,
            onDone: { _ in },
            onSnooze: { _ in }
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
