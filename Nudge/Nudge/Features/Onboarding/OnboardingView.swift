//
//  OnboardingView.swift
//  Nudge
//
//  3-screen penguin-guided onboarding. Skippable. No permissions requested.
//  Page 1: Talk, don't type (brain dump)
//  Page 2: One thing at a time (card view)
//  Page 3: Share anything, see it later (share extension)
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0
    @State private var firstName: String = ""
    @FocusState private var nameFieldFocused: Bool
    
    /// Returns the correct animation respecting Reduce Motion
    private var pageAnimation: Animation {
        AnimationConstants.animation(for: AnimationConstants.pageTransition, reduceMotion: reduceMotion)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button {
                        completeOnboarding()
                    } label: {
                        Text(String(localized: "Skip"))
                            .font(.system(size: 15))
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    .padding(.trailing, DesignTokens.spacingLG)
                    .opacity(currentPage < 2 ? 1 : 0)
                }
                .padding(.top, DesignTokens.spacingSM)
                .frame(height: 44)
                
                // Pages
                TabView(selection: $currentPage) {
                    onboardingPage(
                        penguin: .waving,
                        icon: "mic.fill",
                        title: String(localized: "Meet Nudgy"),
                        subtitle: String(localized: "Your friendly penguin companion. Tap the mic and brain dump everything on your mind — Nudgy splits it into bite-sized tasks."),
                        pageIndex: 0
                    )
                    .tag(0)
                    
                    onboardingPage(
                        penguin: .happy,
                        icon: "square.stack.fill",
                        title: String(localized: "One thing at a time"),
                        subtitle: String(localized: "No overwhelming lists. See one card, handle it, move on. Swipe right to complete, left to snooze."),
                        pageIndex: 1
                    )
                    .tag(1)
                    
                    onboardingPage(
                        penguin: .celebrating,
                        icon: "square.and.arrow.down.fill",
                        title: String(localized: "Share anything, see it later"),
                        subtitle: String(localized: "Share a link, tweet, or note from any app. Pick when you want to be reminded. Nudgy will nudge you."),
                        pageIndex: 2
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(pageAnimation, value: currentPage)
                
                // Page indicator + CTA
                VStack(spacing: DesignTokens.spacingXL) {
                    // Custom page dots
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? DesignTokens.accentActive : DesignTokens.textTertiary)
                                .frame(width: index == currentPage ? 10 : 6, height: index == currentPage ? 10 : 6)
                                .animation(pageAnimation, value: currentPage)
                        }
                    }
                    
                    // Name field (optional, page 3 only)
                    if currentPage == 2 {
                        VStack(spacing: DesignTokens.spacingSM) {
                            TextField(String(localized: "Your first name (optional)"), text: $firstName)
                                .font(AppTheme.body)
                                .foregroundStyle(DesignTokens.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignTokens.spacingLG)
                                .padding(.vertical, DesignTokens.spacingMD)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                        .fill(DesignTokens.cardSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                                                .strokeBorder(DesignTokens.cardBorder, lineWidth: 0.5)
                                        )
                                )
                                .focused($nameFieldFocused)
                                .submitLabel(.done)
                                .textContentType(.givenName)
                                .autocorrectionDisabled()
                                .nudgeAccessibility(
                                    label: String(localized: "Your first name"),
                                    hint: String(localized: "Used to sign off AI-drafted messages. Optional.")
                                )
                            
                            Text(String(localized: "Used to sign off AI-drafted messages"))
                                .font(AppTheme.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .padding(.horizontal, DesignTokens.spacingXL)
                        .transition(.opacity)
                    }
                    
                    // CTA Button
                    if currentPage == 2 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text(String(localized: "Get Started"))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusButton)
                                        .fill(DesignTokens.accentActive)
                                )
                        }
                        .padding(.horizontal, DesignTokens.spacingXL)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, DesignTokens.spacingXXL)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Page Template
    
    private func onboardingPage(
        penguin: PenguinExpression,
        icon: String,
        title: String,
        subtitle: String,
        pageIndex: Int
    ) -> some View {
        VStack(spacing: DesignTokens.spacingXXL) {
            Spacer()
            
            // Penguin with icon overlay
            ZStack {
                PenguinSceneView(
                    size: .large,
                    expressionOverride: penguin
                )
                
                // Floating icon badge
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(DesignTokens.accentActive)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(DesignTokens.cardSurface)
                            .overlay(
                                Circle()
                                    .strokeBorder(DesignTokens.accentActive.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .offset(x: 50, y: -40)
            }
            .opacity(currentPage == pageIndex ? 1 : 0.3)
            .scaleEffect(currentPage == pageIndex ? 1 : 0.8)
            .animation(pageAnimation, value: currentPage)
            
            // Text
            VStack(spacing: DesignTokens.spacingMD) {
                Text(title)
                    .font(AppTheme.displayFont)
                    .foregroundStyle(DesignTokens.textPrimary)
                
                Text(subtitle)
                    .font(AppTheme.body)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, DesignTokens.spacingXL)
            
            Spacer()
            Spacer()
        }
        .nudgeAccessibility(
            label: "\(title). \(subtitle)",
            hint: pageIndex < 2
                ? String(localized: "Swipe left for next page")
                : String(localized: "Tap Get Started to begin"),
            traits: .isStaticText
        )
    }
    
    // MARK: - Actions
    
    private func completeOnboarding() {
        // Save name if provided
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            settings.userName = trimmed
        }
        
        withAnimation(pageAnimation) {
            settings.hasCompletedOnboarding = true
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(AppSettings())
        .environment(PenguinState())
}
