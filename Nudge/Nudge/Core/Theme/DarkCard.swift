//
//  DarkCard.swift
//  Nudge
//
//  Created by Abdullah Imran on 2/7/26.
//

import SwiftUI

// MARK: - Dark Card (Glassmorphism)

/// Reusable glass card component — the primary visual building block of Nudge.
///
/// iOS 26 glassmorphism design:
/// - Background: .ultraThinMaterial with tinted overlay
/// - Border: 0.5px stroke in accent color at low opacity
/// - Corner radius: 20pt (increased for glass feel)
/// - Subtle inner glow for depth
struct DarkCard<Content: View>: View {
    
    let accentColor: Color
    let showPulse: Bool
    let content: Content
    
    @State private var pulseAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(
        accentColor: Color = DesignTokens.accentActive,
        showPulse: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
        self.showPulse = showPulse
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignTokens.spacingLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    // Glass material layer
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(.ultraThinMaterial)
                    
                    // Tinted overlay for depth
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(DesignTokens.cardSurface.opacity(0.5))
                    
                    // Accent glow (top edge)
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.06),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    
                    // Border
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(pulseAnimation && showPulse ? 0.6 : 0.2),
                                    Color.white.opacity(0.05),
                                    accentColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: pulseAnimation && showPulse ? 1.0 : DesignTokens.cardBorderWidth
                        )
                }
            }
            .shadow(color: accentColor.opacity(0.08), radius: 12, y: 4)
            .onAppear {
                if showPulse && !reduceMotion {
                    withAnimation(AnimationConstants.stalePulse) {
                        pulseAnimation = true
                    }
                }
            }
    }
}

// MARK: - Glass Section Card

/// A lighter glass card for settings sections and secondary containers.
struct GlassSection<Content: View>: View {
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignTokens.spacingMD)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .fill(Color.white.opacity(0.03))
                    
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                }
            }
    }
}

// MARK: - Card Variants

extension DarkCard where Content == EmptyView {
    /// Empty card for layout purposes
    init(accentColor: Color = DesignTokens.accentActive) {
        self.accentColor = accentColor
        self.showPulse = false
        self.content = EmptyView()
    }
}

// MARK: - Preview

#Preview("Glass Card — Active") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            DarkCard(accentColor: DesignTokens.accentActive) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("📞")
                        .font(AppTheme.emoji)
                    Text("Call the dentist")
                        .cardTitleStyle()
                    Text("Added 2 hours ago")
                        .secondaryTextStyle()
                }
            }
            
            DarkCard(accentColor: DesignTokens.accentStale, showPulse: true) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("📦")
                        .font(AppTheme.emoji)
                    Text("Buy dog food")
                        .cardTitleStyle()
                    Text("3 days old")
                        .secondaryTextStyle()
                }
            }
            
            DarkCard(accentColor: DesignTokens.accentComplete) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("✅")
                        .font(AppTheme.emoji)
                    Text("Reply to Sarah")
                        .cardTitleStyle()
                        .strikethrough()
                    Text("Done today")
                        .secondaryTextStyle()
                }
            }
            
            GlassSection {
                Text("Glass section example")
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textPrimary)
            }
        }
        .padding()
    }
}
