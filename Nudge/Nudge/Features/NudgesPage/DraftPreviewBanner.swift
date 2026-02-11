//
//  DraftPreviewBanner.swift
//  Nudge
//
//  Inline preview of Nudgy's AI draft on the hero card.
//  Collapsed by default (2 lines), tap to expand.
//  Draft is a PREVIEW — never auto-sent. User confirms in native compose view.
//
//  For CALL tasks, shows "talking points" instead of a script.
//

import SwiftUI

struct DraftPreviewBanner: View {
    
    let item: NudgeItem
    var onRegenerate: (() -> Void)?
    
    @State private var isExpanded = false
    
    private var isCallTask: Bool {
        item.actionType == .call
    }
    
    private var headerLabel: String {
        if isCallTask {
            return String(localized: "Talking points")
        }
        switch item.actionType {
        case .text:  return String(localized: "Draft message")
        case .email: return String(localized: "Draft email")
        default:     return String(localized: "Nudgy's draft")
        }
    }
    
    private var headerIcon: String {
        if isCallTask { return "text.bubble.fill" }
        return "doc.text.fill"
    }
    
    var body: some View {
        if let draft = item.aiDraft, !draft.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // Header row
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                    HapticService.shared.prepare()
                } label: {
                    HStack(spacing: DesignTokens.spacingSM) {
                        Image(systemName: headerIcon)
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.accentActive)
                        
                        Text(headerLabel)
                            .font(AppTheme.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.accentActive)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(AppTheme.captionBold)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                
                // Subject line (email only)
                if isExpanded, let subject = item.aiDraftSubject, !subject.isEmpty {
                    HStack(spacing: 4) {
                        Text(String(localized: "Subject:"))
                            .font(AppTheme.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                        
                        Text(subject)
                            .font(AppTheme.caption.weight(.medium))
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
                
                // Draft body
                Text(draft)
                    .font(AppTheme.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(isExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .animation(.easeOut(duration: 0.2), value: isExpanded)
                
                // Regenerate button (expanded only)
                if isExpanded, let onRegenerate {
                    Button {
                        onRegenerate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(AppTheme.captionBold)
                            
                            Text(String(localized: "Regenerate"))
                                .font(AppTheme.caption.weight(.semibold))
                        }
                        .foregroundStyle(DesignTokens.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(DesignTokens.spacingMD)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                    .fill(DesignTokens.accentActive.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusChip)
                            .strokeBorder(DesignTokens.accentActive.opacity(0.1), lineWidth: 0.5)
                    )
            }
            .nudgeAccessibility(
                label: String(localized: "\(headerLabel): \(draft)"),
                hint: String(localized: "Tap to expand or collapse the draft preview"),
                traits: .isButton
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            let item1 = NudgeItem(content: "Text Sarah about Saturday", emoji: "💬", actionType: .text, contactName: "Sarah", sortOrder: 1)
            let _ = { item1.aiDraft = "Hey Sarah! Just wanted to check in about Saturday — are we still on for brunch at 11?" }()
            DraftPreviewBanner(item: item1, onRegenerate: {})
            
            let item2 = NudgeItem(content: "Call Dr. Patel", emoji: "📞", actionType: .call, contactName: "Dr. Patel", sortOrder: 2)
            let _ = { item2.aiDraft = "Ask about prescription renewal\nConfirm next appointment date\nMention side effects from last medication change" }()
            DraftPreviewBanner(item: item2, onRegenerate: {})
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
