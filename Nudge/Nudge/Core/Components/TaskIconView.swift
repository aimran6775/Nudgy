//
//  TaskIconView.swift
//  Nudge
//
//  Renders a task icon as a crisp SF Symbol inside a tinted circle.
//  Replaces raw emoji text with high-res vector icons.
//
//  Usage:
//    TaskIconView(emoji: item.emoji, actionType: item.actionType, size: .medium)
//
//  The resolver tries:
//    1. Known emoji → SF Symbol mapping (📞 → phone.fill)
//    2. ActionType → its icon (call → phone.fill)
//    3. Fallback → "checklist"
//

import SwiftUI

// MARK: - TaskIconView

struct TaskIconView: View {
    let emoji: String?
    var actionType: ActionType? = nil
    var size: IconSize = .medium
    var accentColor: Color = DesignTokens.accentActive
    
    enum IconSize {
        case small   // 28pt circle, 12pt icon — list rows
        case medium  // 36pt circle, 16pt icon — standard rows
        case large   // 48pt circle, 22pt icon — detail headers
        
        var circleSize: CGFloat {
            switch self {
            case .small:  return 28
            case .medium: return 36
            case .large:  return 48
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small:  return 12
            case .medium: return 16
            case .large:  return 22
            }
        }
    }
    
    private var resolved: (symbol: String, color: Color) {
        TaskIconResolver.resolve(emoji: emoji, actionType: actionType, fallbackColor: accentColor)
    }
    
    var body: some View {
        let icon = resolved
        
        Image(systemName: icon.symbol)
            .font(.system(size: size.iconSize, weight: .semibold))
            .foregroundStyle(icon.color)
            .frame(width: size.circleSize, height: size.circleSize)
            .background(
                Circle()
                    .fill(icon.color.opacity(0.12))
            )
            .nudgeAccessibility(
                label: emoji ?? "Task",
                hint: "",
                traits: .isImage
            )
    }
}

// MARK: - Micro-step icon (smaller, no circle)

struct StepIconView: View {
    let emoji: String
    var size: CGFloat = 14
    
    private var symbol: String {
        TaskIconResolver.resolveSymbol(for: emoji)
    }
    
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(DesignTokens.accentActive)
            .frame(width: size + 4, height: size + 4)
    }
}

// MARK: - Resolver

nonisolated enum TaskIconResolver {
    
    /// Resolve emoji + actionType to an SF Symbol name and color.
    static func resolve(
        emoji: String?,
        actionType: ActionType? = nil,
        fallbackColor: Color = DesignTokens.accentActive
    ) -> (symbol: String, color: Color) {
        // 1. Try emoji mapping
        if let emoji, let mapped = emojiToSymbol[emoji] {
            return mapped
        }
        
        // 2. Try actionType
        if let actionType {
            return (actionType.icon, actionTypeColor(actionType))
        }
        
        // 3. Fallback
        return ("checklist", fallbackColor)
    }
    
    /// Just the symbol name for inline use
    static func resolveSymbol(for emoji: String) -> String {
        emojiToSymbol[emoji]?.symbol ?? microStepSymbol(for: emoji)
    }
    
    // MARK: Emoji → SF Symbol Map
    
    private static let emojiToSymbol: [String: (symbol: String, color: Color)] = [
        // Communication
        "📞": ("phone.fill", DesignTokens.accentActive),
        "📱": ("iphone", DesignTokens.accentActive),
        "💬": ("message.fill", DesignTokens.accentActive),
        "📧": ("envelope.fill", DesignTokens.accentActive),
        "📬": ("envelope.open.fill", DesignTokens.accentActive),
        "📩": ("envelope.badge.fill", DesignTokens.accentActive),
        "✉️": ("envelope.fill", DesignTokens.accentActive),
        
        // People
        "🎂": ("gift.fill", Color(hex: "FF6B9D")),
        "👤": ("person.fill", DesignTokens.accentActive),
        "👥": ("person.2.fill", DesignTokens.accentActive),
        "🤝": ("handshake.fill", DesignTokens.accentActive),
        
        // Health & Wellness
        "💊": ("pills.fill", Color(hex: "34D399")),
        "🏥": ("cross.case.fill", Color(hex: "34D399")),
        "🦷": ("mouth.fill", Color(hex: "34D399")),
        "🧘": ("figure.mind.and.body", Color(hex: "A78BFA")),
        "🏋️": ("dumbbell.fill", Color(hex: "F59E0B")),
        "🏋️‍♂️": ("dumbbell.fill", Color(hex: "F59E0B")),
        "🏋️‍♀️": ("dumbbell.fill", Color(hex: "F59E0B")),
        "🧠": ("brain.head.profile.fill", Color(hex: "A78BFA")),
        
        // Home & Life
        "🪴": ("leaf.fill", Color(hex: "34D399")),
        "🌱": ("leaf.fill", Color(hex: "34D399")),
        "🧹": ("sparkles", Color(hex: "F59E0B")),
        "🏠": ("house.fill", DesignTokens.textSecondary),
        "🛒": ("cart.fill", Color(hex: "60A5FA")),
        "🥗": ("fork.knife", Color(hex: "34D399")),
        "🍳": ("frying.pan.fill", Color(hex: "F59E0B")),
        
        // Animals
        "🐶": ("pawprint.fill", Color(hex: "F59E0B")),
        "🐕": ("pawprint.fill", Color(hex: "F59E0B")),
        "🐱": ("pawprint.fill", Color(hex: "F59E0B")),
        "🐾": ("pawprint.fill", Color(hex: "F59E0B")),
        
        // Work & Productivity
        "📋": ("checklist", DesignTokens.accentActive),
        "📊": ("chart.bar.fill", Color(hex: "60A5FA")),
        "📝": ("doc.text.fill", DesignTokens.textSecondary),
        "✍️": ("pencil.line", Color(hex: "A78BFA")),
        "📌": ("pin.fill", DesignTokens.accentStale),
        "🗓️": ("calendar", Color(hex: "60A5FA")),
        "📅": ("calendar", Color(hex: "60A5FA")),
        "💰": ("dollarsign.circle.fill", Color(hex: "34D399")),
        "🧾": ("doc.text.fill", DesignTokens.textSecondary),
        "💼": ("briefcase.fill", DesignTokens.accentActive),
        "🗂️": ("folder.fill", DesignTokens.textSecondary),
        "📁": ("folder.fill", DesignTokens.textSecondary),
        
        // Tech & Learning
        "💻": ("laptopcomputer", Color(hex: "60A5FA")),
        "🖥️": ("desktopcomputer", Color(hex: "60A5FA")),
        "🎬": ("play.rectangle.fill", Color(hex: "F472B6")),
        "📖": ("book.fill", Color(hex: "A78BFA")),
        "📚": ("books.vertical.fill", Color(hex: "A78BFA")),
        "🎸": ("guitars.fill", Color(hex: "F59E0B")),
        "🎙️": ("mic.fill", Color(hex: "F472B6")),
        "🎵": ("music.note", Color(hex: "F472B6")),
        
        // Travel & Transport
        "✈️": ("airplane", Color(hex: "60A5FA")),
        "🏖️": ("beach.umbrella.fill", Color(hex: "F59E0B")),
        "🚗": ("car.fill", DesignTokens.textSecondary),
        "📦": ("shippingbox.fill", Color(hex: "F59E0B")),
        "🗺️": ("map.fill", Color(hex: "60A5FA")),
        
        // Search & Browse
        "🔍": ("magnifyingglass", DesignTokens.accentActive),
        "🔎": ("magnifyingglass", DesignTokens.accentActive),
        "🌐": ("globe", DesignTokens.accentActive),
        
        // Misc
        "⭐": ("star.fill", Color(hex: "F59E0B")),
        "❤️": ("heart.fill", Color(hex: "FF6B9D")),
        "🎯": ("target", DesignTokens.accentActive),
        "🔔": ("bell.fill", Color(hex: "F59E0B")),
        "⏰": ("alarm.fill", Color(hex: "F59E0B")),
        "🔑": ("key.fill", DesignTokens.textSecondary),
        "🎉": ("party.popper.fill", Color(hex: "F472B6")),
    ]
    
    // MARK: Micro-step emoji → symbol
    
    private static func microStepSymbol(for emoji: String) -> String {
        // Check main map first
        if let mapped = emojiToSymbol[emoji] {
            return mapped.symbol
        }
        // Fallback for common micro-step emoji
        return "circle.fill"
    }
    
    // MARK: ActionType → Color
    
    private static func actionTypeColor(_ type: ActionType) -> Color {
        switch type {
        case .call:          return DesignTokens.accentActive
        case .text:          return DesignTokens.accentActive
        case .email:         return DesignTokens.accentActive
        case .openLink:      return Color(hex: "60A5FA")
        case .search:        return Color(hex: "60A5FA")
        case .navigate:      return Color(hex: "60A5FA")
        case .addToCalendar: return Color(hex: "F59E0B")
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                TaskIconView(emoji: "📞", size: .small)
                TaskIconView(emoji: "📧", size: .medium)
                TaskIconView(emoji: "🐶", size: .large)
            }
            
            HStack(spacing: 16) {
                TaskIconView(emoji: "💊", size: .medium)
                TaskIconView(emoji: "📊", size: .medium)
                TaskIconView(emoji: "🧘", size: .medium)
            }
            
            HStack(spacing: 16) {
                TaskIconView(emoji: nil, actionType: .call, size: .medium)
                TaskIconView(emoji: nil, actionType: .email, size: .medium)
                TaskIconView(emoji: nil, size: .medium)
            }
            
            HStack(spacing: 12) {
                StepIconView(emoji: "📱")
                StepIconView(emoji: "🔍")
                StepIconView(emoji: "📞")
            }
        }
    }
    .preferredColorScheme(.dark)
}
