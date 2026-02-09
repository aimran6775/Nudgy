//
//  AppTheme.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

// MARK: - App Theme

enum AppTheme {
    
    // MARK: Typography
    // Uses SF Pro (system) with Dynamic Type support throughout
    // Defined as static properties so they can be used directly: `.font(AppTheme.body)`
    
    /// Large display text — empty state messages, onboarding headings
    static let displayFont: Font = .system(.largeTitle, design: .default, weight: .bold)
    
    /// Card task title — the main text users read
    static let taskTitle: Font = .system(.title2, design: .default, weight: .semibold)
    
    /// Section headers, button labels
    static let headline: Font = .system(.headline, design: .default, weight: .semibold)
    
    /// Body text — descriptions, draft previews
    static let body: Font = .system(.body, design: .default, weight: .regular)
    
    /// Secondary text — timestamps, metadata, hints
    static let caption: Font = .system(.caption, design: .default, weight: .regular)
    
    /// Small labels — queue position, counts
    static let footnote: Font = .system(.footnote, design: .default, weight: .regular)
    
    /// Rounded variant for mascot-adjacent UI (friendly feel)
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
    
    /// Nudgy's speech bubble text — rounded, friendly, slightly warm
    static let nudgyBubbleFont: Font = .system(.callout, design: .rounded, weight: .medium)
    
    /// Nudgy's name label — used below the penguin when shown large
    static let nudgyNameFont: Font = .system(.caption2, design: .rounded, weight: .semibold)
    
    /// Emoji display — large emoji on cards. Use `emoji(size:)` for custom sizes.
    static let emoji: Font = .system(size: 32)
    
    /// Emoji at a custom size
    static func emoji(size: CGFloat) -> Font {
        .system(size: size)
    }
}

// MARK: - View Modifiers for Consistent Styling

struct CardTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.taskTitle)
            .foregroundStyle(DesignTokens.textPrimary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }
}

struct SecondaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.caption)
            .foregroundStyle(DesignTokens.textSecondary)
    }
}

struct TertiaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.footnote)
            .foregroundStyle(DesignTokens.textTertiary)
    }
}

struct AccentButtonStyle: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(AppTheme.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.spacingLG)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton))
    }
}

// MARK: - View Extension Shortcuts

extension View {
    func cardTitleStyle() -> some View {
        modifier(CardTitleStyle())
    }
    
    func secondaryTextStyle() -> some View {
        modifier(SecondaryTextStyle())
    }
    
    func tertiaryTextStyle() -> some View {
        modifier(TertiaryTextStyle())
    }
    
    func accentButtonStyle(color: Color = DesignTokens.accentActive) -> some View {
        modifier(AccentButtonStyle(color: color))
    }
}
