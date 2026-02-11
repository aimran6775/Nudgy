//
//  ActionCTAButton.swift
//  Nudge
//
//  The primary call-to-action button on the hero card.
//  Adapts based on what the task IS:
//  - CALL → "📞 Call [Contact]"
//  - TEXT → "💬 Text [Contact]"
//  - EMAIL → "✉️ Email [Contact]"
//  - LINK → "🔗 Open Link"
//  - Has estimated time → "▶ Start Focus"
//  - Generic → "✓ I did it"
//
//  Every card has ONE primary action. Never a passive display.
//

import SwiftUI

struct ActionCTAButton: View {
    
    let item: NudgeItem
    let onAction: () -> Void
    let onDone: () -> Void
    let onFocus: (() -> Void)?
    
    /// Determines the CTA variant
    private var ctaVariant: CTAVariant {
        if let actionType = item.actionType {
            switch actionType {
            case .call:          return .call
            case .text:          return .text
            case .email:         return .email
            case .openLink:      return .openLink
            case .search:        return .search
            case .navigate:      return .navigate
            case .addToCalendar: return .calendar
            }
        }
        if item.estimatedMinutes != nil, onFocus != nil {
            return .focus
        }
        return .done
    }
    
    var body: some View {
        Button {
            HapticService.shared.actionButtonTap()
            switch ctaVariant {
            case .call, .text, .email, .openLink, .search, .navigate, .calendar:
                onAction()
            case .focus:
                onFocus?()
            case .done:
                onDone()
            }
        } label: {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: ctaVariant.icon)
                    .font(AppTheme.body.weight(.semibold))
                
                Text(ctaLabel)
                    .font(AppTheme.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingMD)
            .background {
                Capsule()
                    .fill(ctaVariant.color)
                    .shadow(color: ctaVariant.color.opacity(0.3), radius: 8, y: 4)
            }
        }
        .buttonStyle(.plain)
        .nudgeAccessibility(
            label: ctaLabel,
            hint: String(localized: "Performs the primary action for this task"),
            traits: .isButton
        )
    }
    
    // MARK: - Label Logic
    
    private var ctaLabel: String {
        switch ctaVariant {
        case .call:
            if let contact = item.contactName, !contact.isEmpty {
                return String(localized: "Call \(contact)")
            }
            return String(localized: "Call")
        case .text:
            if let contact = item.contactName, !contact.isEmpty {
                return String(localized: "Text \(contact)")
            }
            return String(localized: "Send Text")
        case .email:
            if let contact = item.contactName, !contact.isEmpty {
                return String(localized: "Email \(contact)")
            }
            return String(localized: "Send Email")
        case .openLink:
            return String(localized: "Open Link")
        case .search:
            return String(localized: "Search")
        case .navigate:
            return String(localized: "Navigate")
        case .calendar:
            return String(localized: "Add to Calendar")
        case .focus:
            if let mins = item.estimatedMinutes {
                return String(localized: "Start Focus · \(mins) min")
            }
            return String(localized: "Start Focus")
        case .done:
            return String(localized: "I did it ✓")
        }
    }
}

// MARK: - CTA Variant

private enum CTAVariant {
    case call, text, email, openLink, search, navigate, calendar
    case focus
    case done
    
    var icon: String {
        switch self {
        case .call:     return "phone.fill"
        case .text:     return "message.fill"
        case .email:    return "envelope.fill"
        case .openLink: return "link"
        case .search:   return "magnifyingglass"
        case .navigate: return "map.fill"
        case .calendar: return "calendar.badge.plus"
        case .focus:    return "timer"
        case .done:     return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .call:     return DesignTokens.accentComplete
        case .text:     return DesignTokens.accentActive
        case .email:    return DesignTokens.accentActive
        case .openLink: return DesignTokens.accentIndigo
        case .search:   return DesignTokens.accentIndigo
        case .navigate: return DesignTokens.accentStale
        case .calendar: return DesignTokens.accentStale
        case .focus:    return DesignTokens.accentFocus
        case .done:     return DesignTokens.accentComplete
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            ActionCTAButton(
                item: NudgeItem(content: "Call Dr. Patel", emoji: "📞", actionType: .call, contactName: "Dr. Patel", sortOrder: 1),
                onAction: {},
                onDone: {},
                onFocus: nil
            )
            
            ActionCTAButton(
                item: NudgeItem(content: "Text Sarah", emoji: "💬", actionType: .text, contactName: "Sarah", sortOrder: 2),
                onAction: {},
                onDone: {},
                onFocus: nil
            )
            
            ActionCTAButton(
                item: NudgeItem(content: "Buy groceries", emoji: "🛒", sortOrder: 3),
                onAction: {},
                onDone: {},
                onFocus: {}
            )
            
            ActionCTAButton(
                item: NudgeItem(content: "Do laundry", emoji: "👕", sortOrder: 4),
                onAction: {},
                onDone: {},
                onFocus: nil
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
